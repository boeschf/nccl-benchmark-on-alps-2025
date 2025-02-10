import os
import re
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

# Set Seaborn style for better aesthetics
sns.set_style("whitegrid")

# Path
RESULTS_DIR = "results"
PLOTS_DIR = "plots"
os.makedirs(PLOTS_DIR, exist_ok=True)

# Regex pattern to match job result CSV files
JOB_FILE_PATTERN = re.compile(r"job-n-\d{5}-N-(\d{4})\.csv")
IDENTIFIER_PATTERN = re.compile(r"nccl-tests/nccl-([\d.\-]+)-aws-([\d.\-]+):.*$")


# Storage for parsed data
data_store = {}

# Iterate through each subdirectory in the results folder
for config_folder in os.listdir(RESULTS_DIR):
    config_path = os.path.join(RESULTS_DIR, config_folder)

    # Ensure it's a directory and contains identifier.txt
    identifier_file = os.path.join(config_path, "identifier.txt")
    if not os.path.isdir(config_path) or not os.path.exists(identifier_file):
        continue

    # Read the identifier for this configuration
    with open(identifier_file, "r") as f:
        identifier = f.readline().strip()

    # Extract NCCL and AWS versions and modify the identifier
    match = IDENTIFIER_PATTERN.search(identifier)
    if match:
        nccl_version = match.group(1)
        aws_version = match.group(2)
        identifier = identifier[:match.start()] + f"nccl@{nccl_version}_aws@{aws_version}"
    else:
        print(f"Failed to extract NCCL and AWS versions from identifier. {identifier}")

    # Initialize storage for this configuration
    data_store[identifier] = {}

    # Iterate over run_xxxx directories within the configuration
    for run_folder in sorted(os.listdir(config_path)):
        run_path = os.path.join(config_path, run_folder)
        if not os.path.isdir(run_path) or not run_folder.startswith("run_"):
            continue  # Skip if not a run directory

        # Iterate over CSV files in the configuration directory
        for filename in os.listdir(run_path):
            match = JOB_FILE_PATTERN.match(filename)
            if not match:
                continue  # Skip files that do not match the pattern

            # Extract the number of nodes from filename
            num_nodes = int(match.group(1))

            # Filter out runs with fewer than 4 nodes
            if num_nodes < 4:
                continue

            # Read the CSV file into a DataFrame
            csv_path = os.path.join(run_path, filename)
            print(f"Reading: {csv_path}")
            df = pd.read_csv(csv_path)

            # Store the data indexed by identifier and number of nodes
            if num_nodes not in data_store[identifier]:
                data_store[identifier][num_nodes] = []
            data_store[identifier][num_nodes].append(df)

# Function to create bar plots for each message size
def plot_busbw_vs_nodes(data_store):
    all_message_sizes = set()

    # Collect all unique message sizes from all data
    for identifier, node_data in data_store.items():
        for num_nodes, dfs in node_data.items():
            if dfs:
                all_message_sizes.update(dfs[0].iloc[:, 0])  # First column is message size

    all_message_sizes = sorted(all_message_sizes)  # Ensure sorted order

    # Iterate over each message size
    for message_size in all_message_sizes:
        print(f"message size = {message_size}")
        message_size_mib = message_size / (1024 * 1024)  # Convert bytes to MiB

        fig, ax = plt.subplots(figsize=(16, 7))

        configs = list(data_store.keys())
        node_counts = sorted(set(num_nodes for identifier in data_store for num_nodes in data_store[identifier]))

        # Create a DataFrame to store aggregated data
        plot_data = []
        for identifier in configs:
            for num_nodes in node_counts:
                if num_nodes in data_store[identifier]:
                    dfs = data_store[identifier][num_nodes]
                    num_runs = len(dfs)  # Count number of runs
                    combined_df = pd.concat(dfs)  # Merge multiple runs
                    row = combined_df[combined_df.iloc[:, 0] == message_size]  # Find rows matching message size
                    if not row.empty:
                        busbw_median = row["busbw"].median()
                        busbw_min = row["busbw"].min()
                        busbw_max = row["busbw"].max()
                        has_errors = (row["#wrong"] > 0).any()  # Check if any errors exist

                        plot_data.append({
                            "Nodes": num_nodes,
                            "Config": identifier,
                            "Bus Bandwidth (GB/s)": busbw_median,
                            "Min": busbw_min,
                            "Max": busbw_max,
                            "Has Errors": has_errors,
                            "Num Runs": num_runs  # Store number of runs
                        })


        # Convert to Pandas DataFrame
        plot_df = pd.DataFrame(plot_data)
        if plot_df.empty:
            print(f"Skipping plot for message size {message_size}, no data found.")
            continue

        # Sort plot_df by Nodes to match Seaborn's rendering order
        plot_df.sort_values(by=["Config", "Nodes"], inplace=True)

        # Create bar plot with min-max error bars
        #bars = sns.barplot(data=plot_df, x="Nodes", y="Bus Bandwidth", hue="Config", dodge=True, palette="tab10", ax=ax)
        bars = sns.barplot(
            data=plot_df, x="Nodes", y="Bus Bandwidth (GB/s)", hue="Config", dodge=True,
            palette="tab10", ax=ax, errorbar=None
        )

        # Add min-max error bars manually
        for bar, (_, row) in zip(bars.patches, plot_df.iterrows()):
            ax.errorbar(
                x=bar.get_x() + bar.get_width() / 2,
                y=row["Bus Bandwidth (GB/s)"],
                yerr=[[row["Bus Bandwidth (GB/s)"] - row["Min"]], [row["Max"] - row["Bus Bandwidth (GB/s)"]]],
                fmt="none", capsize=5, capthick=2, color="black", alpha=0.7
            )

        # Apply hatching for bars where #wrong > 0
        for bar, (_, row) in zip(bars.patches, plot_df.iterrows()):
            if row["Has Errors"]:
                bar.set_hatch("//")  # Apply hatch pattern for errors
                bar.set_edgecolor("black")  # Ensure hatch is visible

        # Approximate text height in data coordinates
        fontsize_points = 10  # Font size in points
        fig_to_data = ax.transData.inverted().transform  # Convert figure to data coords
        _, text_height = fig_to_data((0, fontsize_points))  # Convert font size to data space

        # Add text above bars to indicate number of runs
        for bar, (_, row) in zip(bars.patches, plot_df.iterrows()):
            ax.text(
                bar.get_x() + bar.get_width() / 2,  # Center text above bar
                row["Max"] - 0.05*text_height, # - 1.02*text_height,  # Slightly above the bar
                f"{row['Num Runs']}",  # Display number of runs
                ha="center", va="bottom", fontsize=10, fontweight="bold", color="black"
            )

        # Adjust legend position
        #plt.legend(title="Configurations", fontsize=8, title_fontsize=10, loc="upper left", bbox_to_anchor=(1, 1))
        plt.legend(title="Configurations", fontsize=9, title_fontsize=10, loc="upper center",
                   bbox_to_anchor=(0.5, -0.2), ncol=1, frameon=False)

        # Improve readability
        plt.xlabel("Number of Nodes", fontsize=12)
        plt.ylabel("Bus Bandwidth (GB/s)", fontsize=12)
        plt.title(f"Bus Bandwidth vs Nodes for Message Size {message_size} B ({message_size_mib:.2f} MiB)", fontsize=14)

        # Adjust tick labels
        plt.xticks(fontsize=10)
        plt.yticks(fontsize=10)

        # Tight layout and save plot
        plt.tight_layout(rect=[0, 0, 0.85, 1])  # Leave space for legend
        save_path_png = os.path.join(PLOTS_DIR, f"busbw_vs_nodes_{message_size}.png")
        save_path_svg = os.path.join(PLOTS_DIR, f"busbw_vs_nodes_{message_size}.svg")
        plt.savefig(save_path_png, dpi=400, bbox_inches="tight")
        plt.savefig(save_path_svg, format="svg", bbox_inches="tight")
        print(f"  Saved plot: {save_path_png}")
        print(f"  Saved plot: {save_path_svg}")
        plt.close(fig)


# Run the plotting function
plot_busbw_vs_nodes(data_store)

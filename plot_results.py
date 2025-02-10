import os
import re
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

# Set Seaborn style for better aesthetics
sns.set_style("whitegrid")

# Path
RESULTS_DIR = "results_fixed_hsn"
PLOTS_DIR = "plots_fixed_hsn"
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

    # Iterate over CSV files in the configuration directory
    for filename in os.listdir(config_path):
        match = JOB_FILE_PATTERN.match(filename)
        if not match:
            continue  # Skip files that do not match the pattern

        # Extract the number of nodes from filename
        num_nodes = int(match.group(1))

        # Filter out runs with fewer than 4 nodes
        if num_nodes < 4:
            continue

        # Read the CSV file into a DataFrame
        csv_path = os.path.join(config_path, filename)
        print(f"Reading: {csv_path}")
        df = pd.read_csv(csv_path)

        # Store the data indexed by identifier and number of nodes
        data_store[identifier][num_nodes] = df

# Verify data structure
print("Parsed Data Structure:")
for identifier, node_data in data_store.items():
    print(f"Config: {identifier}")
    for num_nodes, df in node_data.items():
        print(f"  Nodes: {num_nodes}, Rows: {len(df)}, Columns: {list(df.columns)}")

# Function to create bar plots for each message size
def plot_busbw_vs_nodes(data_store):
    all_message_sizes = set()

    # Collect all unique message sizes from all data
    for identifier, node_data in data_store.items():
        for num_nodes, df in node_data.items():
            all_message_sizes.update(df.iloc[:, 0])  # First column is message size

    all_message_sizes = sorted(all_message_sizes)  # Ensure sorted order

    # Iterate over each message size
    for message_size in all_message_sizes:
        print(f"message size = {message_size}")
        message_size_mib = message_size / (1024 * 1024)  # Convert bytes to MiB

        fig, ax = plt.subplots(figsize=(16, 7))

        configs = list(data_store.keys())
        node_counts = sorted(set(num_nodes for identifier in data_store for num_nodes in data_store[identifier]))

        # Create a DataFrame to store the extracted data
        plot_data = []
        for identifier in configs:
            for num_nodes in node_counts:
                if num_nodes in data_store[identifier]:
                    df = data_store[identifier][num_nodes]
                    row = df[df.iloc[:, 0] == message_size]  # Find row matching message size
                    if not row.empty:
                        busbw_value = row["busbw"].values[0]  # Extract busbw
                        has_errors = (row["#wrong"].values[0] > 0)  # Check if any errors exist
                        plot_data.append({"Nodes": num_nodes, "Config": identifier, "Bus Bandwidth": busbw_value, "Has Errors": has_errors})

        # Convert to Pandas DataFrame
        plot_df = pd.DataFrame(plot_data)
        plot_df.sort_values(by="Config", inplace=True)

        if plot_df.empty:
            print(f"Skipping plot for message size {message_size}, no data found.")
            continue

        bars = sns.barplot(data=plot_df, x="Nodes", y="Bus Bandwidth", hue="Config", dodge=True, palette="tab10", ax=ax)

        # Apply hatching for bars where #wrong > 0
        for bar, (_, row) in zip(bars.patches, plot_df.iterrows()):
            if row["Has Errors"]:
                bar.set_hatch("//")  # Apply hatch pattern for errors
                bar.set_edgecolor("black")  # Ensure hatch is visible

        # Adjust legend size
        #plt.legend(title="Configurations", fontsize=8, title_fontsize=10, loc="upper left", bbox_to_anchor=(1, 1))
        plt.legend(title="Configurations", fontsize=9, title_fontsize=10, loc="upper center",
                   bbox_to_anchor=(0.5, -0.2), ncol=1, frameon=True)


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

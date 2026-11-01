# Multi-Agent Frontier Exploration and Map Merging

A Godot simulation in which deterministic agents explore an unknown grid world. Each agent maintains a local map, discovers its surroundings, and can exchange maps with nearby agents. When communication and the Contract Net Protocol (CNP) are enabled, agents can also coordinate the allocation of exploration tasks.

## Requirements

- **Godot Engine 4.7.2 stable, Standard edition** ([official download page](https://godotengine.org/download/archive/4.7.2-stable/)). Choose the download for your operating system. The .NET edition is not required.

## Download and run

1. Download Godot 4.7.2 from the link above and open it.
2. Download the repository from GitHub then extract the archive or clone it:

   ```bash
   git clone git@github.com:HugoGellida/Projet-SMA-Avance.git
   ```
3. Open Godot,then click Import and select the downloaded project folder or its `project.godot` file. Import and open the project.
4. In Godot's **FileSystem** panel, open `main_scene.tscn` in the project root.
5. Click **Run Current Scene**. You can also click **Run Project**: `main_scene.tscn` is the configured main scene.
6. The simulation opens paused. Click **Start** to begin.

## Using the simulation

- **Settings**: Before starting, set the square map size, target obstacle density, number of agents, and each agent's speed, vision range, communication range, and color. Click **Apply** to generate the configured simulation.
- **Start / Pause**: Run or pause the simulation. **Step** advances it by one simulation step while paused; an agent may move multiple cells in one step depending on its speed.
- **Communication**: Allow agents within each other's communication range to exchange their local maps. **CNP** enables task allocation and requires communication; enabling CNP also enables communication.
- **Reset**: Restart the simulation paused with the current configuration, map seed, and spawn seed. Settings are locked after **Start** or **Step**; use **Reset** to make them editable again.
- **Global map**: Use the mouse wheel or the `+` / `−` buttons to zoom, drag to pan, and click **Fit** or press `F` to show the full map.
- **Agent maps** show each agent's current knowledge. The **visit heat map** shows how often agents have visited each cell, while **Statistics** displays the simulation's measurements.

Large or obstacle-dense maps can take time to generate.

# BISCUIT & MIDAP Container - Usage Guide

## Overview

This container provides a complete GPU-enabled environment for bioimage analysis with:
- **BISCUIT**: Jupyter-based interactive tool for benchmarking cell segmentation algorithms
- **MIDAP**: GUI-based platform for automated microscopy data analysis

## Building the Container

```bash
# Build the container image (may take 30-60 minutes)
apptainer build biscuit-midap.sif biscuit-midap-complete.def

# Verify the build
apptainer inspect biscuit-midap.sif
```

## Quick Start

### 1. Jupyter Notebook Mode (Default)

```bash
# Interactive session
srun --gres=gpu:1 --mem=32G --cpus-per-task=8 --pty bash
apptainer run --nv biscuit-midap.sif

# SLURM job submission
sbatch run_biscuit_midap.sh
```

### 2. MIDAP GUI Mode

```bash
# Set mode to GUI
export MODE=gui
sbatch run_biscuit_midap.sh

# Access via browser at: http://<node-hostname>:6080/vnc.html
```

### 3. Both Services Simultaneously

```bash
# Run both Jupyter and GUI
export MODE=both
sbatch run_biscuit_midap.sh
```

## SLURM Script Configuration

Edit the SLURM script header to customize resources:

```bash
#SBATCH --time=08:00:00        # Adjust runtime
#SBATCH --mem=32G              # Adjust memory
#SBATCH --cpus-per-task=8      # Adjust CPU cores
#SBATCH --gres=gpu:1           # Request GPU
```

### Environment Variables

```bash
# Set before submission
export MODE=jupyter              # jupyter|gui|both
export CONTAINER_IMAGE=/path/to/biscuit-midap.sif
export WORK_DIR=/scratch/username/project
export JUPYTER_PORT=8888
export NOVNC_PORT=6080

sbatch run_biscuit_midap.sh
```

## Accessing Services

### Option A: Direct Access (if on campus network)

After job starts, check the connection info file:
```bash
cat connection_info_<JOB_ID>.txt
```

Access URLs directly from the file.

### Option B: SSH Tunnel (remote access)

1. **For Jupyter:**
```bash
# On your local machine
ssh -L 8888:compute-node:8888 username@hpc-login-node

# Then open: http://localhost:8888
```

2. **For NoVNC/MIDAP GUI:**
```bash
# On your local machine
ssh -L 6080:compute-node:6080 username@hpc-login-node

# Then open: http://localhost:6080/vnc.html
```

3. **Both services:**
```bash
# Combined tunnel
ssh -L 8888:compute-node:8888 -L 6080:compute-node:6080 username@hpc-login-node
```

## Using BISCUIT

### Checking Pre-installed Environment

In your Jupyter notebook:

```python
import os

MARKER = "/content/.biscuit_env_ready"

if os.path.exists(MARKER):
    print("✓ BISCUIT environment is ready!")
    print("All dependencies are pre-installed.")
else:
    print("✗ Environment marker not found.")
```

### Example Workflow

```python
# Import BISCUIT
from midap.apps import biscuit_workflow

# All dependencies are already installed:
# - TensorFlow 2.18.0
# - Cellpose, StarDist, Omnipose
# - Custom segmentation models
# - All required packages

# Start your analysis
# ... your code here ...
```

### Available Segmentation Models

Pre-downloaded models via `biscuit_download --force`:
- Cellpose models (cyto, cyto2, nuclei, etc.)
- StarDist models
- Omnipose models
- Custom UNet models

## Using MIDAP GUI

1. Submit job in GUI mode:
```bash
export MODE=gui
sbatch run_biscuit_midap.sh
```

2. Access NoVNC interface at the URL provided

3. MIDAP GUI will launch automatically in the VNC session

4. Load your microscopy data and run analysis pipelines

## Container Features

### Pre-installed Software

| Category | Tools |
|----------|-------|
| **Segmentation** | Cellpose, StarDist, Omnipose, UNet |
| **Deep Learning** | TensorFlow 2.18.0, PyTorch (via bioimageio) |
| **Tracking** | btrack 0.4.6 |
| **Visualization** | Napari, matplotlib, ipympl |
| **File Formats** | BioimageIO core (ONNX, PyTorch) |

### Python Environment

- Python 3.12
- Virtual environment at `/opt/biscuit-venv`
- All dependencies from `setup.py` included
- Additional packages from both notebooks installed

### System Features

- CUDA 12.3.2 for GPU support
- NoVNC for remote GUI access
- TigerVNC server
- Fluxbox window manager

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU availability inside container
apptainer exec --nv biscuit-midap.sif nvidia-smi

# Ensure --nv flag is used
apptainer run --nv biscuit-midap.sif
```

### Port Already in Use

The SLURM script automatically finds available ports. Check the connection info file for actual ports used.

### NoVNC Won't Connect

1. Verify the VNC server is running:
```bash
# In job output, look for VNC startup messages
```

2. Check firewall rules on the compute node

3. Ensure SSH tunnel is set up correctly

### Jupyter Token

Find the Jupyter token in the job output file:
```bash
# Look for lines like:
# http://hostname:8888/?token=abc123...
```

### Out of Memory

Increase memory allocation:
```bash
#SBATCH --mem=64G  # or higher
```

## Data Management

### Bind Mounts

The SLURM script automatically binds:
- `$WORK_DIR` → `/workspace` (working directory)
- `/scratch` → `/scratch` (if exists)
- `/data` → `/data` (if exists)
- `/home` → `/home` (if exists)

### Custom Bind Mounts

Edit the SLURM script:
```bash
BIND_MOUNTS="$WORK_DIR:/workspace,/custom/path:/mount/point"
```

### Saving Results

All work in `/workspace` persists to `$WORK_DIR` on the host system.

## Performance Tips

1. **Use GPU acceleration**: Always use `--nv` flag and request GPU
2. **Optimize memory**: Monitor usage and adjust `--mem` accordingly
3. **CPU cores**: Use `--cpus-per-task` to match your data processing needs
4. **Storage**: Use fast scratch storage for active analysis

## Example Workflows

### Simple Segmentation Benchmark

```bash
# 1. Submit Jupyter job
sbatch run_biscuit_midap.sh

# 2. Open notebook and run:
from midap.apps import biscuit_workflow
# Load example data
# Compare Cellpose vs StarDist
# Generate benchmark report
```

### Bacterial Growth Analysis (MIDAP)

```bash
# 1. Submit GUI job
export MODE=gui
sbatch run_biscuit_midap.sh

# 2. Access NoVNC in browser
# 3. Load time-lapse microscopy data
# 4. Configure segmentation and tracking
# 5. Run automated analysis
# 6. Manual correction if needed
# 7. Export results
```

### Combined Analysis

```bash
# 1. Run both services
export MODE=both
sbatch run_biscuit_midap.sh

# 2. Use Jupyter for initial model testing
# 3. Switch to MIDAP GUI for full pipeline
# 4. Return to Jupyter for custom analysis
```

## Getting Help

- **BISCUIT Documentation**: https://biscuit.let-your-data-speak.com/
- **MIDAP Repository**: https://github.com/Microbial-Systems-Ecology/midap
- **Check container help**: `apptainer run-help biscuit-midap.sif`
- **Job output**: Check `biscuit-midap-<JOB_ID>.out` for logs

## Version Information

- Container Version: 2.0.0
- Python: 3.12
- TensorFlow: 2.18.0
- CUDA: 12.3.2
- Base OS: Rocky Linux 9

---

**Note**: First-time container build downloads several GB of data including models and dependencies. This is a one-time operation. Subsequent runs use the cached image.
#!/bin/bash
#SBATCH --job-name=biscuit-midap
#SBATCH --partition=GPU-interactive
#SBATCH --time=08:00:00
#SBATCH --mem=32G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:1
#SBATCH --output=logs/biscuit-midap-%j.log

# Create logs directory if it doesn't exist
mkdir -p logs

# ==============================================================================
# BISCUIT & MIDAP Container Launcher for HPC
# ==============================================================================
# This script launches the BISCUIT/MIDAP container with GPU support
# Supporting both Jupyter notebooks and MIDAP GUI via NoVNC
# ==============================================================================

# Load required modules
module load apptainer/1.1.7

# Configuration
MODE="${MODE:-jupyter}"  # Options: jupyter, gui, both
CONTAINER_IMAGE="${CONTAINER_IMAGE:-/gpfs/soma_fs/scratch/containers/biscuit-rocky.sif}"
WORK_DIR="${WORK_DIR:-$PWD}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

# ==============================================================================
# Setup
# ==============================================================================

echo "========================================================================"
echo "BISCUIT & MIDAP Container Launcher"
echo "========================================================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Mode: $MODE"
echo "Working Directory: $WORK_DIR"
echo "Container: $CONTAINER_IMAGE"
echo "========================================================================"

# Create runtime directories
#export APPTAINER_CACHEDIR="${WORK_DIR}/.apptainer/cache"
#export APPTAINER_TMPDIR="${WORK_DIR}/.apptainer/tmp"
#mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

# Get node hostname and IP for connection info
NODE_HOSTNAME=$(hostname)
NODE_IP=$(hostname -i | awk '{print $1}')

# ==============================================================================
# Port Management
# ==============================================================================

# Function to find an available port
find_available_port() {
    local start_port=$1
    local port=$start_port
    while netstat -tuln | grep -q ":$port "; do
        port=$((port + 1))
    done
    echo $port
}

# Check and adjust ports if needed
JUPYTER_PORT=$(find_available_port $JUPYTER_PORT)
NOVNC_PORT=$(find_available_port $NOVNC_PORT)

echo "Assigned Ports:"
echo "  Jupyter: $JUPYTER_PORT"
echo "  NoVNC: $NOVNC_PORT"
echo "========================================================================"

# ==============================================================================
# Create Connection Information File
# ==============================================================================

CONNECTION_INFO="${WORK_DIR}/connection_info_${SLURM_JOB_ID}.txt"

cat > "$CONNECTION_INFO" << EOF
======================================================================
BISCUIT & MIDAP Connection Information
======================================================================
Job ID: $SLURM_JOB_ID
Node: $NODE_HOSTNAME
IP Address: $NODE_IP
Mode: $MODE
Start Time: $(date)

----------------------------------------------------------------------
EOF

if [ "$MODE" = "jupyter" ] || [ "$MODE" = "both" ]; then
    cat >> "$CONNECTION_INFO" << EOF
JUPYTER NOTEBOOK:
----------------------------------------------------------------------
Access URL: http://${NODE_HOSTNAME}:${JUPYTER_PORT}

If using SSH tunnel from your local machine:
  ssh -L ${JUPYTER_PORT}:${NODE_HOSTNAME}:${JUPYTER_PORT} <username>@<hpc-login-node>
  Then access: http://localhost:${JUPYTER_PORT}

----------------------------------------------------------------------
EOF
fi

if [ "$MODE" = "gui" ] || [ "$MODE" = "both" ]; then
    cat >> "$CONNECTION_INFO" << EOF
MIDAP GUI (NoVNC):
----------------------------------------------------------------------
Access URL: http://${NODE_HOSTNAME}:${NOVNC_PORT}/vnc.html

If using SSH tunnel from your local machine:
  ssh -L ${NOVNC_PORT}:${NODE_HOSTNAME}:${NOVNC_PORT} <username>@<hpc-login-node>
  Then access: http://localhost:${NOVNC_PORT}/vnc.html

----------------------------------------------------------------------
EOF
fi

cat >> "$CONNECTION_INFO" << EOF

NOTES:
- The Jupyter token will be displayed in the job output file
- For NoVNC, no password is required (use the 'Connect' button)
- To stop the job: scancel $SLURM_JOB_ID
- Working directory: $WORK_DIR

======================================================================
EOF

cat "$CONNECTION_INFO"

# ==============================================================================
# Setup Environment Variables for Container
# ==============================================================================

export JUPYTER_PORT
export NOVNC_PORT
export HOME=$WORK_DIR
export USER=${USER:-$(whoami)}

# ==============================================================================
# Launch Container
# ==============================================================================

echo ""
echo "Starting container in $MODE mode..."
echo "Output will appear below. Press Ctrl+C to stop."
echo "========================================================================"
echo ""

# Bind mounts for data access
BIND_MOUNTS="$WORK_DIR:/workspace"

# Add common HPC data directories if they exist
[ -d "/scratch" ] && BIND_MOUNTS="$BIND_MOUNTS,/scratch"
[ -d "/gpfs" ] && BIND_MOUNTS="$BIND_MOUNTS,/gpfs"
[ -d "/data" ] && BIND_MOUNTS="$BIND_MOUNTS,/data"

# Launch the container based on mode
if [ "$MODE" = "jupyter" ]; then
    apptainer exec --nv \
        --bind "$BIND_MOUNTS" \
        --pwd /workspace \
        "$CONTAINER_IMAGE" \
        /opt/biscuit-venv/bin/python -m jupyter notebook \
            --ip=0.0.0.0 \
            --port=$JUPYTER_PORT \
            --no-browser \
            --allow-root \
            --notebook-dir=/workspace

elif [ "$MODE" = "gui" ]; then
    # For GUI mode, we need to set up the display
    export DISPLAY=:1
    apptainer exec --nv \
        --bind "$BIND_MOUNTS" \
        --pwd /workspace \
        "$CONTAINER_IMAGE" \
        /opt/scripts/start_services.sh gui

elif [ "$MODE" = "both" ]; then
    # Start both services
    export DISPLAY=:1
    apptainer exec --nv \
        --bind "$BIND_MOUNTS" \
        --pwd /workspace \
        "$CONTAINER_IMAGE" \
        bash -c "/opt/scripts/start_vnc.sh && sleep 3 && /opt/scripts/start_midap_gui.sh & /opt/biscuit-venv/bin/python -m jupyter notebook --ip=0.0.0.0 --port=$JUPYTER_PORT --no-browser --allow-root --notebook-dir=/workspace"

else
    echo "ERROR: Invalid MODE specified: $MODE"
    echo "Valid options are: jupyter, gui, both"
    exit 1
fi

# ==============================================================================
# Cleanup
# ==============================================================================

echo ""
echo "========================================================================"
echo "Container stopped at $(date)"
echo "Connection info saved to: $CONNECTION_INFO"
echo "========================================================================"

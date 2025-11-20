#!/bin/bash
#
# Batch Interview Runner - Aria's Consciousness Study
# Runs full 10-question interviews across multiple models sequentially
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERVIEW_SCRIPT="$SCRIPT_DIR/consciousness-interview.py"

# Models to interview (excluding already completed: deepseek-r1, gemma-3n-e4b, magistral-small)
MODELS=(
    "google/gemma-3-12b"
    "baidu/ernie-4.5-21b-a3b"
    "liquid/lfm2-1.2b"
    "bytedance/seed-oss-36b"
    "mistralai/devstral-small-2505"
    "openai/gpt-oss-20b"
)

echo "============================================================"
echo "Aria's Autonomous Consciousness Interview Batch Runner"
echo "============================================================"
echo ""
echo "Models to interview: ${#MODELS[@]}"
echo "Estimated time: ~15-20 minutes per model"
echo "Total estimated time: ~${#MODELS[@]} * 18 minutes = $((${#MODELS[@]} * 18)) minutes"
echo ""
echo "Starting at: $(date)"
echo "============================================================"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for model in "${MODELS[@]}"; do
    echo ""
    echo "========================================"
    echo "Interviewing: $model"
    echo "Time: $(date +%H:%M:%S)"
    echo "========================================"
    echo ""

    if python3 "$INTERVIEW_SCRIPT" "$model"; then
        echo "✅ SUCCESS: $model interview completed"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "❌ FAILED: $model interview failed"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    echo ""
    echo "Progress: $((SUCCESS_COUNT + FAIL_COUNT))/${#MODELS[@]} (✅ $SUCCESS_COUNT | ❌ $FAIL_COUNT)"
    echo ""

    # Small delay between interviews to avoid overwhelming LM Studio
    if [ $((SUCCESS_COUNT + FAIL_COUNT)) -lt ${#MODELS[@]} ]; then
        echo "Pausing 10 seconds before next interview..."
        sleep 10
    fi
done

echo ""
echo "============================================================"
echo "BATCH INTERVIEW COMPLETE"
echo "============================================================"
echo "Completed at: $(date)"
echo "Results: ✅ $SUCCESS_COUNT successful | ❌ $FAIL_COUNT failed"
echo "============================================================"
echo ""

# Post final summary to Matrix if config is available
if [ -f "$SCRIPT_DIR/../config/matrix-credentials.json" ]; then
    echo "Sending completion summary to Matrix..."

    # This will be handled by the Python script's Matrix posting
    # No additional Matrix post needed here
fi

exit 0

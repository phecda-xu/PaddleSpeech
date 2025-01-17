#!/bin/bash

stage=3
stop_stage=100

config_path=$1
ge2e_ckpt_path=$2

# gen speaker embedding
if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    python3 ${MAIN_ROOT}/paddlespeech/vector/exps/ge2e/inference.py \
        --input=~/datasets/data_aishell3/train/wav/ \
        --output=dump/embed \
        --checkpoint_path=${ge2e_ckpt_path}
fi

# copy from tts3/preprocess
if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    # get durations from MFA's result
    echo "Generate durations.txt from MFA results ..."
    python3 ${MAIN_ROOT}/utils/gen_duration_from_textgrid.py \
        --inputdir=./aishell3_alignment_tone \
        --output durations.txt \
        --config=${config_path}
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    # extract features
    echo "Extract features ..."
    python3 ${BIN_DIR}/preprocess.py \
        --dataset=aishell3 \
        --rootdir=~/datasets/data_aishell3/ \
        --dumpdir=dump \
        --dur-file=durations.txt \
        --config=${config_path} \
        --num-cpu=20 \
        --cut-sil=True \
        --spk_emb_dir=dump/embed
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    # get features' stats(mean and std)
    echo "Get features' stats ..."
    python3 ${MAIN_ROOT}/utils/compute_statistics.py \
        --metadata=dump/train/raw/metadata.jsonl \
        --field-name="speech"
fi

if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    # normalize and covert phone to id, dev and test should use train's stats
    echo "Normalize ..."
    python3 ${BIN_DIR}/normalize.py \
        --metadata=dump/train/raw/metadata.jsonl \
        --dumpdir=dump/train/norm \
        --speech-stats=dump/train/speech_stats.npy \
        --phones-dict=dump/phone_id_map.txt \
        --speaker-dict=dump/speaker_id_map.txt

    python3 ${BIN_DIR}/normalize.py \
        --metadata=dump/dev/raw/metadata.jsonl \
        --dumpdir=dump/dev/norm \
        --speech-stats=dump/train/speech_stats.npy \
        --phones-dict=dump/phone_id_map.txt \
        --speaker-dict=dump/speaker_id_map.txt

    python3 ${BIN_DIR}/normalize.py \
        --metadata=dump/test/raw/metadata.jsonl \
        --dumpdir=dump/test/norm \
        --speech-stats=dump/train/speech_stats.npy \
        --phones-dict=dump/phone_id_map.txt \
        --speaker-dict=dump/speaker_id_map.txt
fi

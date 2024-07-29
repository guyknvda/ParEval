#!/bin/bash
python generate/generate.py --prompts prompts/generation-prompts.json --model codellama/CodeLlama-7b-hf --output outputs/output.json --max_new_tokens 1024 --num_samples_per_prompt 5 --do_sample --temperature 0.2 --top_p 0.95 --prompted --restart --batch_size 16

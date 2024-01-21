#!/bin/python3
""" Run all the generated code.
    author: Daniel Nichols
    date: October 2023
"""
# std imports
from argparse import ArgumentParser
import json
import logging
import os
import tempfile
from typing import Optional

# tpl imports
from tqdm import tqdm

# local imports
from driver_wrapper import DriverWrapper
from cpp.cpp_driver_wrapper import CppDriverWrapper
from util import await_input, load_json


""" Map language names to driver wrappers """
LANGUAGE_DRIVERS = {
    "cpp": CppDriverWrapper,
}

def get_args():
    parser = ArgumentParser(description="Run all the generated code.")
    parser.add_argument("input_json", type=str, help="Input JSON file containing the test cases.")
    parser.add_argument("-o", "--output", type=str, help="Output JSON file containing the results.")
    parser.add_argument("--scratch-dir", type=str, help="If provided, put scratch files here.")
    parser.add_argument("--launch-configs", type=str, default="launch-configs.json", 
        help="config for how to run samples.")
    parser.add_argument("--problem-sizes", type=str, default="problem-sizes.json", 
        help="config for how to run samples.")
    parser.add_argument("--yes-to-all", action="store_true", help="If provided, automatically answer yes to all prompts.")
    parser.add_argument("--dry", action="store_true", help="Dry run. Do not actually run the code snippets.")
    parser.add_argument("--overwrite", action="store_true", help="If ouputs are already in DB for a given prompt, \
        then overwrite them. Default behavior is to skip existing results.")
    parser.add_argument("--hide-progress", action="store_true", help="If provided, do not show progress bar.")
    model_group = parser.add_mutually_exclusive_group()
    model_group.add_argument("--exclude-models", nargs="+", type=str, choices=["serial", "omp", "mpi", "mpi+omp", "kokkos", "cuda", "hip"], 
        help="Exclude the given parallelism models from testing.")
    model_group.add_argument("--include-models", nargs="+", type=str, choices=["serial", "omp", "mpi", "mpi+omp", "kokkos", "cuda", "hip"],
        help="Only test the given parallelism models.")
    model_group = parser.add_mutually_exclusive_group()
    model_group.add_argument("--problem", type=str, help="Only test this probem if provided.")
    model_group.add_argument("--problem-type", type=str, help="Only test problems of this type if provided.")
    parser.add_argument("--early-exit-runs", action="store_true", help="If provided, stop evaluating a model output after the first run configuration fails.")
    parser.add_argument("--build-timeout", type=int, default=30, help="Timeout in seconds for building a program.")
    parser.add_argument("--run-timeout", type=int, default=120, help="Timeout in seconds for running a program.")
    parser.add_argument("--log", choices=["INFO", "DEBUG", "WARNING", "ERROR", "CRITICAL"], default="INFO",
        type=str.upper, help="logging level")
    parser.add_argument("--log-build-errors", action="store_true", help="On build error, display the stderr of the build process.")
    return parser.parse_args()

def get_driver(prompt: dict, scratch_dir: Optional[os.PathLike], launch_configs: dict, problem_sizes: dict, dry: bool, **kwargs) -> DriverWrapper:
    """ Get the language drive wrapper for this prompt """
    driver_cls = LANGUAGE_DRIVERS[prompt["language"]]
    return driver_cls(parallelism_model=prompt["parallelism_model"], launch_configs=launch_configs, 
        problem_sizes=problem_sizes, scratch_dir=scratch_dir, dry=dry, **kwargs)

def already_has_results(prompt: dict) -> bool:
    """ Check if a prompt already has results stored in it. """
    if "outputs" not in prompt or not isinstance(prompt["outputs"], list):
        raise ValueError(f"Prompt {prompt.get('name', 'unknown')} does not have any outputs.")
    
    outputs = prompt["outputs"]
    if len(outputs) == 0 or all(isinstance(o, str) for o in outputs):
        return False

    if len(outputs) > 0 and all(isinstance(o, dict) for o in outputs):
        return True

    raise ValueError(f"Prompt {prompt.get('name', 'unknown')} has invalid outputs.")

def main():
    args = get_args()

    # setup logging
    numeric_level = getattr(logging, args.log.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError("Invalid log level: {}".format(args.log))
    logging.basicConfig(format="%(asctime)s [%(levelname)s] -- %(message)s", level=numeric_level)

    # warn user before continuing
    logging.warning("This script will compile and run code generated by an LLM. " +
        "It is recommended that you run this script in a sandboxed environment.")
    if not args.yes_to_all:
        response = await_input("Continue? [y/n] ", lambda r: r.lower() in ["y", "n", "yes", "no"])
        if response.lower() in ["n", "no"]:
            logging.info("Exiting.")
            return

    # load in the generated text
    data = load_json(args.input_json)
    logging.info(f"Loaded {len(data)} prompts from {args.input_json}.")

    # load launch configs
    launch_configs = load_json(args.launch_configs)
    logging.info(f"Loaded launch configs from {args.launch_configs}.")

    # load problem sizes
    problem_sizes = load_json(args.problem_sizes)
    logging.info(f"Loaded problem sizes from {args.problem_sizes}.")

    # gather the list of parallelism models to test
    models_to_test = args.include_models if args.include_models else ["serial", "omp", "mpi", "mpi+omp", "kokkos", "cuda", "hip"]
    if args.exclude_models:
        models_to_test = [m for m in models_to_test if m not in args.exclude_models]

    # run each prompt
    all_prompts = data if args.hide_progress else tqdm(data, desc="Testing prompts")
    for prompt in all_prompts:
        if prompt["parallelism_model"] not in models_to_test:
            logging.debug(f"Skipping prompt {prompt['name']} because it uses {prompt['parallelism_model']}.")
            continue

        if args.problem and prompt["name"] != args.problem:
            logging.debug(f"Skipping prompt {prompt['name']} because it is not {args.problem}.")
            continue

        if args.problem_type and prompt["problem_type"] != args.problem_type:
            logging.debug(f"Skipping prompt {prompt['name']} because it is not {args.problem_type}.")
            continue

        if already_has_results(prompt):
            if args.overwrite:
                logging.debug(f"Prompt {prompt['name']} already has results. Overwriting.")
                prompt["outputs"] = [p["generated_output"] for p in prompt["outputs"]]
            else:
                logging.debug(f"Skipping prompt {prompt['name']} because it already has results. \
                    Use --overwrite to overwrite existing results.")
                continue

        driver = get_driver(
            prompt, 
            args.scratch_dir, 
            launch_configs, 
            problem_sizes,
            args.dry, 
            display_build_errors=args.log_build_errors,
            early_exit_runs=args.early_exit_runs,
            build_timeout=args.build_timeout,
            run_timeout=args.run_timeout
        )
        driver.test_all_outputs_in_prompt(prompt)

        # go ahead and write out outputs now
        if args.output and args.output != '-':
            with open(args.output, "w") as fp:
                json.dump(data, fp, indent=4)
            logging.debug(f"Wrote intermediate results to {args.output}.")

    # write out results
    if args.output and args.output != '-':
        with open(args.output, "w") as fp:
            json.dump(data, fp, indent=4)
        logging.info(f"Wrote results to {args.output}.")
    else:
        print(json.dumps(data, indent=4))

if __name__ == "__main__":
    main()
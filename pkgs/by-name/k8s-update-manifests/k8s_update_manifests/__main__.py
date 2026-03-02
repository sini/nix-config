"""Main entry point for k8s-update-manifests."""

import argparse
import logging
import sys
from pathlib import Path

from .environment import EnvironmentManager
from .models import EnvironmentMetadata
from .utils import GitUtils, NixUtils


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments.

    Returns:
        Parsed arguments namespace
    """
    parser = argparse.ArgumentParser(
        description="Update Kubernetes manifests for nixidy environments"
    )
    parser.add_argument(
        "--git-root",
        type=Path,
        help="Git repository root path (auto-detected if not specified)",
    )
    parser.add_argument(
        "--flake",
        type=str,
        default=".",
        help="Flake reference to use (default: current directory)",
    )
    parser.add_argument(
        "--system",
        type=str,
        help="System platform (auto-detected if not specified)",
    )
    parser.add_argument(
        "--env",
        type=str,
        action="append",
        dest="environments",
        help="Specific environment(s) to process (can be specified multiple times; processes all if not specified)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be changed without actually making changes",
    )
    parser.add_argument(
        "--skip-secrets",
        action="store_true",
        help="Exclude secret files from processing",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )

    return parser.parse_args()


def configure_logging(dry_run: bool, verbose: bool) -> None:
    """Configure logging based on options.

    Args:
        dry_run: If True, enable debug logging
        verbose: If True, enable debug logging
    """
    logging.basicConfig(
        level=logging.DEBUG if (dry_run or verbose) else logging.INFO,
        format="%(levelname)s: %(message)s",
    )


def validate_git_root(args: argparse.Namespace) -> Path:
    """Validate and return git repository root.

    Args:
        args: Parsed command line arguments

    Returns:
        Validated git root path

    Raises:
        SystemExit: If git root is invalid or not found
    """
    if args.git_root:
        git_root = args.git_root.resolve()
        if not git_root.exists():
            logging.error(f"specified git root does not exist: {git_root}")
            sys.exit(1)
        return git_root

    git_root = GitUtils.get_root()
    if git_root is None:
        logging.error("not running from within a git repository")
        sys.exit(1)
    return git_root


def discover_and_filter_environments(
    flake_ref: str,
    system: str,
    requested_envs: list[str] | None,
) -> list[str]:
    """Discover and filter environments.

    Args:
        flake_ref: Flake reference
        system: System platform
        requested_envs: Optional list of requested environment names

    Returns:
        List of environment names to process

    Raises:
        SystemExit: If no environments found or requested environments don't exist
    """
    logging.info(f"Discovering environments for system: {system or 'auto-detect'}")
    env_names = NixUtils.discover_environments(flake_ref, system)

    if not env_names:
        logging.error("No environments found in flake")
        sys.exit(1)

    # Filter to specific environments if requested
    if requested_envs:
        requested_set = set(requested_envs)
        available_set = set(env_names)
        missing_envs = requested_set - available_set
        if missing_envs:
            logging.error(
                f"Requested environments not found: {', '.join(sorted(missing_envs))}"
            )
            logging.error(f"Available environments: {', '.join(sorted(available_set))}")
            sys.exit(1)
        env_names = [e for e in env_names if e in requested_set]

    return env_names


def resolve_output_path(metadata: EnvironmentMetadata, git_root: Path) -> Path:
    """Resolve output path to absolute path.

    Args:
        metadata: Environment metadata
        git_root: Git repository root

    Returns:
        Absolute output path
    """
    output_path_str = str(metadata.output_path)
    if output_path_str.startswith("./"):
        return git_root / output_path_str.lstrip("./")
    return metadata.output_path


def process_environment(
    env: str,
    flake_ref: str,
    system: str,
    git_root: Path,
    dry_run: bool,
    skip_secrets: bool,
) -> None:
    """Process a single environment.

    Args:
        env: Environment name
        flake_ref: Flake reference
        system: System platform
        git_root: Git repository root
        dry_run: If True, don't write changes
        skip_secrets: If True, don't process secrets
    """
    logging.info(f"Processing environment: {env}")

    # Get metadata for this environment
    metadata = NixUtils.get_environment_metadata(flake_ref, env, system)

    # Resolve output path to absolute path
    output_path = resolve_output_path(metadata, git_root)

    # Update metadata with absolute path
    metadata = EnvironmentMetadata(
        name=metadata.name,
        repository=metadata.repository,
        branch=metadata.branch,
        output_path=output_path,
    )

    # Build the environment package
    logging.info("Building environment package...")
    src_path = NixUtils.build_environment_package(flake_ref, env, system)
    logging.info(f"Built: {src_path}")

    # Update the environment
    environment_manager = EnvironmentManager(
        src_path,
        metadata,
        git_root=git_root,
        dry_run=dry_run,
        skip_secrets=skip_secrets,
    )
    environment_manager.update()
    logging.info("")


def main() -> int:
    """Main entry point.

    Returns:
        Exit code (0 for success, non-zero for failure)
    """
    args = parse_arguments()
    configure_logging(args.dry_run, args.verbose)

    # Validate git repository root
    git_root = validate_git_root(args)

    # Log initial information
    if args.dry_run:
        logging.info("DRY RUN MODE: No changes will be made")
        logging.info("")

    if args.skip_secrets:
        logging.info("SKIP SECRETS MODE: Secret files will be excluded from processing")
        logging.info("")

    logging.info(f"Git repository root: {git_root}")
    logging.info(f"Flake reference: {args.flake}")

    # Discover and filter environments
    env_names = discover_and_filter_environments(
        args.flake, args.system, args.environments
    )

    logging.info(
        f"Processing {len(env_names)} environment(s): {', '.join(sorted(env_names))}"
    )
    logging.info("")

    # Process each environment
    for env in sorted(env_names):
        process_environment(
            env,
            args.flake,
            args.system,
            git_root,
            args.dry_run,
            args.skip_secrets,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())

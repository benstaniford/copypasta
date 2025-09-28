import subprocess
import os
import logging

logger = logging.getLogger(__name__)

def get_version():
    """
    Get the current application version from git tags or fallback to a default.
    Returns the version string in the format 'v1.0.0' or fallback.
    """
    try:
        # Try to get version from git tags
        result = subprocess.run(
            ['git', 'describe', '--tags', '--always'],
            cwd=os.path.dirname(__file__),
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            version = result.stdout.strip()
            if version:
                logger.debug(f"Version from git: {version}")
                return version
        else:
            logger.warning(f"Git describe failed with return code {result.returncode}: {result.stderr}")
    
    except subprocess.TimeoutExpired:
        logger.warning("Git command timed out")
    except FileNotFoundError:
        logger.warning("Git command not found")
    except Exception as e:
        logger.warning(f"Error getting version from git: {e}")
    
    # Fallback to environment variable or default
    fallback_version = os.environ.get('APP_VERSION', 'v0.0.0-unknown')
    logger.info(f"Using fallback version: {fallback_version}")
    return fallback_version

def get_numeric_version(version_string=None):
    """
    Convert version string to numeric format (remove 'v' prefix).
    Example: 'v1.0.0' -> '1.0.0'
    """
    if version_string is None:
        version_string = get_version()
    
    # Remove 'v' prefix if present
    if version_string.startswith('v'):
        return version_string[1:]
    return version_string

# Cache the version to avoid calling git multiple times
_cached_version = None

def get_cached_version():
    """Get cached version to avoid repeated git calls"""
    global _cached_version
    if _cached_version is None:
        _cached_version = get_version()
    return _cached_version
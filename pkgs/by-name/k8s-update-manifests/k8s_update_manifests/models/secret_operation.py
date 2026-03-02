"""Secret operation enumeration."""

from enum import Enum


class SecretOperation(Enum):
    """Operations that can be performed on secrets."""

    CREATE = 1
    DELETE = 2
    UPDATE = 3
    NOOP = 4

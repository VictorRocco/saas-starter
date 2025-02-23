#!/usr/bin/env python3
import json
import sys
import os
from pathlib import Path
from typing import Optional, Dict, Any

def get_project_root() -> Path:
    return Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def read_tracking_file(file_path: str) -> Optional[Dict[str, Any]]:
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
            # Ensure project_name is an absolute path
            if 'project_name' in data:
                data['project_name'] = str(get_project_root() / data['project_name'])
            return data
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def write_tracking_file(file_path: str, data: Dict[str, Any]) -> bool:
    try:
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except Exception:
        return False

def get_tracking_param(file_path: str, param_name: str) -> Optional[str]:
    data = read_tracking_file(file_path)
    if data and param_name in data:
        return str(data[param_name])
    return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: utils.py <action> <file_path> [param_name] [value]")
        sys.exit(1)

    action = sys.argv[1]
    file_path = sys.argv[2]

    if action == "read":
        if len(sys.argv) != 4:
            sys.exit(1)
        param_name = sys.argv[3]
        value = get_tracking_param(file_path, param_name)
        if value:
            print(value)
            sys.exit(0)
        sys.exit(1)

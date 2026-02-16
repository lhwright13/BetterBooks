#!/usr/bin/env python3

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


class Colors:
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RESET = '\033[0m'

    TOP_LEFT = '\u250c'
    BOTTOM_LEFT = '\u2514'
    HORIZONTAL = '\u2500'
    VERTICAL = '\u2502'
    TEE_RIGHT = '\u251c'


def colorize(text: str, color: str, use_color: bool = True) -> str:
    if use_color:
        return f"{color}{text}{Colors.RESET}"
    return text


def truncate(text: str, max_len: int = 80) -> str:
    if len(text) <= max_len:
        return text
    return text[:max_len - 3] + "..."


def format_timestamp(ts: str) -> str:
    try:
        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
        return dt.strftime("%H:%M:%S")
    except (ValueError, AttributeError):
        return ts[:8] if len(ts) >= 8 else ts


def load_logs(log_dir: Path, date: Optional[str] = None) -> List[Dict[str, Any]]:
    date = date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    log_file = log_dir / f"{date}.jsonl"
    if not log_file.exists():
        return []
    with open(log_file, 'r', encoding='utf-8') as f:
        return [json.loads(line) for line in f if line.strip()]


def filter_logs(
    logs: List[Dict[str, Any]],
    book: Optional[str] = None,
    persona: Optional[str] = None,
    request_id: Optional[str] = None
) -> List[Dict[str, Any]]:
    filtered = logs

    if book:
        filtered = [l for l in filtered if book.lower() in l.get('context', {}).get('book_id', '').lower()]

    if persona:
        filtered = [l for l in filtered if persona.lower() in l.get('context', {}).get('persona_id', '').lower()]

    if request_id:
        filtered = [l for l in filtered if request_id in l.get('request_id', '')]

    return filtered


def print_summary(log: Dict[str, Any], use_color: bool = True):
    request_id = log.get('request_id', 'unknown')
    timestamp = format_timestamp(log.get('timestamp', ''))
    user_msg = truncate(log.get('user', {}).get('message', ''), 50)
    book_id = log.get('context', {}).get('book_id', 'unknown')
    persona_id = log.get('context', {}).get('persona_id', 'unknown')
    latency = log.get('response', {}).get('latency_ms', 0)
    response_len = len(log.get('response', {}).get('text', ''))

    line = f"[{colorize(timestamp, Colors.DIM, use_color)}] "
    line += f"[{colorize(request_id, Colors.CYAN, use_color)}] "
    line += f'"{user_msg}" '
    line += colorize(f"| {book_id} ", Colors.DIM, use_color)
    line += colorize(f"| {persona_id} ", Colors.DIM, use_color)
    line += colorize(f"| {latency:.0f}ms ", Colors.DIM, use_color)
    line += colorize(f"| {response_len} chars", Colors.DIM, use_color)

    print(line)


def print_full(log: Dict[str, Any], use_color: bool = True):
    request_id = log.get('request_id', 'unknown')
    timestamp = log.get('timestamp', '')
    user = log.get('user', {})
    context = log.get('context', {})
    response = log.get('response', {})

    header = f"{Colors.TOP_LEFT}{Colors.HORIZONTAL} CHAT [{request_id}] @ {timestamp} "
    header += Colors.HORIZONTAL * (70 - len(f" CHAT [{request_id}] @ {timestamp} "))
    print(colorize(header, Colors.CYAN, use_color))

    print(colorize(f"{Colors.VERTICAL} ", Colors.CYAN, use_color) +
          colorize("USER", Colors.BOLD, use_color))
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"ID: {user.get('id', 'unknown')}")
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Message: \"{user.get('message', '')}\"")

    print(colorize(f"{Colors.TEE_RIGHT}{Colors.HORIZONTAL} CONTEXT ", Colors.CYAN, use_color) +
          colorize(Colors.HORIZONTAL * 60, Colors.CYAN, use_color))
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Book: {context.get('book_id', 'unknown')}")
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Chapter: {context.get('chapter', '?')} @ {context.get('timestamp_seconds', 0):.1f}s")
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Persona: {context.get('persona_name', context.get('persona_id', 'unknown'))}")
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Chapters included: {context.get('chapters_included', [])}")
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Token estimate: {context.get('token_estimate', 0):,}")

    system_prompt = context.get('system_prompt', '')
    if system_prompt:
        print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
              colorize("System Prompt:", Colors.BOLD, use_color))
        for i in range(0, len(system_prompt), 80):
            chunk = system_prompt[i:i+80]
            print(colorize(f"{Colors.VERTICAL}     ", Colors.CYAN, use_color) +
                  colorize(chunk, Colors.DIM, use_color))

    print(colorize(f"{Colors.TEE_RIGHT}{Colors.HORIZONTAL} RESPONSE ", Colors.CYAN, use_color) +
          colorize(Colors.HORIZONTAL * 59, Colors.CYAN, use_color))
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Model: {response.get('model', 'unknown')}")
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          f"Latency: {response.get('latency_ms', 0):.0f}ms")
    print(colorize(f"{Colors.VERTICAL}   ", Colors.CYAN, use_color) +
          colorize("Text:", Colors.BOLD, use_color))

    response_text = response.get('text', '')
    for i in range(0, len(response_text), 80):
        chunk = response_text[i:i+80]
        print(colorize(f"{Colors.VERTICAL}     ", Colors.CYAN, use_color) +
              colorize(chunk, Colors.GREEN, use_color))

    footer = f"{Colors.BOTTOM_LEFT}" + Colors.HORIZONTAL * 71
    print(colorize(footer, Colors.CYAN, use_color))
    print()


def list_available_dates(log_dir: Path):
    if not log_dir.exists():
        print("No log directory found.")
        return

    log_files = sorted(log_dir.glob("*.jsonl"))
    if not log_files:
        print("No log files found.")
        return

    print("Available log dates:")
    for f in log_files:
        date = f.stem
        count = sum(1 for line in open(f) if line.strip())
        print(f"  {date}: {count} interactions")


def main():
    parser = argparse.ArgumentParser(
        description="View AI chat interaction logs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                           View today's logs (summary)
  %(prog)s --date 2025-11-27         View specific date
  %(prog)s --book "Great Gatsby"     Filter by book title
  %(prog)s --persona gatsby          Filter by persona
  %(prog)s --request abc123 --full   Show full details for a request
  %(prog)s --tail 5                  Show last 5 interactions
  %(prog)s --list-dates              Show available log dates
  %(prog)s --no-color                Disable colors (for piping)
        """
    )

    parser.add_argument('--date', '-d', help='Date to view (YYYY-MM-DD), default is today')
    parser.add_argument('--book', '-b', help='Filter by book title (partial match)')
    parser.add_argument('--persona', '-p', help='Filter by persona ID (partial match)')
    parser.add_argument('--request', '-r', help='Filter by request ID')
    parser.add_argument('--full', '-f', action='store_true', help='Show full details')
    parser.add_argument('--tail', '-t', type=int, help='Show last N interactions')
    parser.add_argument('--list-dates', '-l', action='store_true', help='List available log dates')
    parser.add_argument('--no-color', action='store_true', help='Disable colored output')
    parser.add_argument('--log-dir', default='./logs/chat_interactions',
                        help='Log directory path (default: ./logs/chat_interactions)')

    args = parser.parse_args()

    log_dir = Path(args.log_dir)
    use_color = not args.no_color and sys.stdout.isatty()

    if args.list_dates:
        list_available_dates(log_dir)
        return

    if not log_dir.exists():
        print(f"Log directory not found: {log_dir}")
        print("No chat interactions have been logged yet.")
        return

    logs = load_logs(log_dir, args.date)
    if not logs:
        date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
        print(f"No logs found for {date_str}")
        print("Use --list-dates to see available dates.")
        return

    logs = filter_logs(logs, args.book, args.persona, args.request)
    if not logs:
        print("No logs match the filter criteria.")
        return

    if args.tail:
        logs = logs[-args.tail:]

    if args.full or args.request:
        for log in logs:
            print_full(log, use_color)
    else:
        print(f"Found {len(logs)} interactions:\n")
        for log in logs:
            print_summary(log, use_color)


if __name__ == "__main__":
    main()

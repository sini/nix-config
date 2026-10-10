"""Benchmark one OpenAI-compatible /v1 endpoint: speed, tool-call parsing, reasoning runaway, recall.

    llm-bench --base http://10.9.2.2:8081/v1 [--key K] [--only perf,tools,reasoning,niah]
              [--prefill 4096,32768] [--concurrency 1,2,4] [--niah 32768,131072]
              [--replay request.json] [--out results.json]

One row per measurement on stdout. Every prompt starts with a fresh nonce so a prefix cache never
serves a measurement. --replay takes a recorded chat/completions body (e.g. den-ag-design's
pi:p1:e1); it runs as recorded and with every boolean tool parameter removed.
"""

import argparse
import copy
import json
import random
import sys
import threading
import time
import urllib.error
import urllib.request

FILLER = (
    "Line {i}: the archive notes that shipment {i} left the northern depot on schedule, "
    "was inspected twice, and arrived without incident.\n"
)


def nonce():
    return f"[run {random.getrandbits(48):012x}]\n"


class Client:
    def __init__(self, base, key, timeout, omit_effort=False):
        self.base, self.key, self.timeout = base.rstrip("/"), key, timeout
        self.omit_effort = omit_effort

    def _req(self, path, body=None):
        headers = {"content-type": "application/json"}
        if self.key:
            headers["authorization"] = f"Bearer {self.key}"
        data = None if body is None else json.dumps(body).encode()
        return urllib.request.urlopen(
            urllib.request.Request(self.base + path, data=data, headers=headers),
            timeout=self.timeout,
        )

    def model(self):
        return json.load(self._req("/models"))["data"][0]["id"]

    def chat(self, body):
        """Stream one completion; return timings, usage, text, reasoning, tool calls, finish reason."""
        body = {**body, "stream": True, "stream_options": {"include_usage": True}}
        if self.omit_effort:
            # Templates without an effort knob (e.g. Qwen3.6) reject the field outright.
            body.pop("reasoning_effort", None)
        t0 = time.monotonic()
        first = None
        out = {
            "text": "",
            "reasoning": "",
            "tool_calls": {},
            "finish": None,
            "usage": None,
        }
        with self._req("/chat/completions", body) as r:
            for raw in r:
                line = raw.decode().strip()
                if not line.startswith("data:") or line == "data: [DONE]":
                    continue
                chunk = json.loads(line[5:])
                if chunk.get("usage"):
                    out["usage"] = chunk["usage"]
                for ch in chunk.get("choices") or []:
                    d = ch.get("delta") or {}
                    piece = (d.get("content") or "") + (
                        d.get("reasoning_content") or d.get("reasoning") or ""
                    )
                    if piece or d.get("tool_calls"):
                        first = first or time.monotonic()
                    out["text"] += d.get("content") or ""
                    out["reasoning"] += (
                        d.get("reasoning_content") or d.get("reasoning") or ""
                    )
                    for tc in d.get("tool_calls") or []:
                        slot = out["tool_calls"].setdefault(
                            tc.get("index", 0), {"name": "", "arguments": ""}
                        )
                        fn = tc.get("function") or {}
                        slot["name"] += fn.get("name") or ""
                        slot["arguments"] += fn.get("arguments") or ""
                    out["finish"] = ch.get("finish_reason") or out["finish"]
        out["t_total"] = time.monotonic() - t0
        out["ttft"] = (first or time.monotonic()) - t0
        out["tool_calls"] = list(out["tool_calls"].values())
        return out


def filler(tokens):
    # ~32 tokens per line on Qwen's tokenizer (measured); the reported prompt_tokens is the real size.
    return "".join(FILLER.format(i=i) for i in range(max(1, tokens // 32)))


def row(results, section, **kv):
    results.append({"section": section, **kv})
    print(
        section,
        " ".join(
            f"{k}={v:.1f}" if isinstance(v, float) else f"{k}={v}"
            for k, v in kv.items()
        ),
        flush=True,
    )


def decode_rate(r):
    toks = (r["usage"] or {}).get("completion_tokens", 0)
    span = r["t_total"] - r["ttft"]
    return toks / span if span > 0 else 0.0


def perf(c, model, a, results):
    base = {
        "model": model,
        "temperature": 0,
        "max_tokens": 512,
        "reasoning_effort": "low",
    }
    story = "Write a 400-word story about a lighthouse keeper."
    r = c.chat({**base, "messages": [{"role": "user", "content": nonce() + story}]})
    row(
        results,
        "decode",
        ttft_s=r["ttft"],
        completion_tokens=r["usage"]["completion_tokens"],
        tok_s=decode_rate(r),
    )
    for n in a.prefill:
        msg = nonce() + filler(n) + "\nReply with the single word OK."
        r = c.chat(
            {**base, "max_tokens": 16, "messages": [{"role": "user", "content": msg}]}
        )
        pt = r["usage"]["prompt_tokens"]
        row(
            results,
            "prefill",
            target=n,
            prompt_tokens=pt,
            ttft_s=r["ttft"],
            tok_s=pt / r["ttft"],
        )
    for n in a.concurrency:
        rs = [None] * n

        def go(i, rs=rs):
            rs[i] = c.chat(
                {**base, "messages": [{"role": "user", "content": nonce() + story}]}
            )

        t0 = time.monotonic()
        ts = [threading.Thread(target=go, args=(i,)) for i in range(n)]
        for t in ts:
            t.start()
        for t in ts:
            t.join()
        wall = time.monotonic() - t0
        toks = sum(r["usage"]["completion_tokens"] for r in rs)
        row(
            results,
            "concurrency",
            n=n,
            wall_s=wall,
            aggregate_tok_s=toks / wall,
            per_stream_tok_s=sum(decode_rate(r) for r in rs) / n,
        )


def tool_verdict(r):
    """pass: parsed as a tool call. leaked: the call came back as <tool_call> text."""
    if r["tool_calls"]:
        return "pass"
    return "leaked" if "<tool_call>" in r["text"] else "no-call"


def drop_booleans(body):
    body = copy.deepcopy(body)
    for t in body.get("tools") or []:
        p = t["function"].get("parameters") or {}
        gone = [
            k
            for k, s in (p.get("properties") or {}).items()
            if s.get("type") == "boolean"
        ]
        for k in gone:
            p["properties"].pop(k)
        p["required"] = [k for k in p.get("required", []) if k not in gone]
    return body


def tools(c, model, a, results):
    arms = {
        "bool": ({"type": "boolean"}, "Call the tool t with x set to false."),
        "str": ({"type": "string"}, "Call the tool t with x set to the word no."),
    }
    for arm, (schema, msg) in arms.items():
        for i in range(3):
            body = {
                "model": model,
                "temperature": 0,
                "reasoning_effort": "low",
                "max_tokens": 4096,
                "messages": [{"role": "user", "content": msg}],
                "tools": [
                    {
                        "type": "function",
                        "function": {
                            "name": "t",
                            "description": "test tool",
                            "parameters": {
                                "type": "object",
                                "required": ["x"],
                                "properties": {"x": schema},
                            },
                        },
                    }
                ],
            }
            r = c.chat(body)
            row(
                results,
                "tool-probe",
                arm=arm,
                run=i,
                verdict=tool_verdict(r),
                finish=r["finish"],
                args=json.dumps([t["arguments"] for t in r["tool_calls"]]),
            )
    if a.replay:
        with open(a.replay) as f:
            rec = json.load(f)
        rec = rec.get("request", rec)
        for arm, body in (("recorded", rec), ("no-booleans", drop_booleans(rec))):
            r = c.chat({**body, "model": model})
            row(
                results,
                "tool-replay",
                arm=arm,
                verdict=tool_verdict(r),
                finish=r["finish"],
                calls=",".join(t["name"] for t in r["tool_calls"]) or "-",
            )


def reasoning(c, model, a, results):
    q = "A bat and a ball cost 1.10 in total. The bat costs 1.00 more than the ball. What does the ball cost?"
    for effort in (
        ("default",) if a.effort == "omit" else ("low", "medium", "high", "xhigh")
    ):
        try:
            r = c.chat(
                {
                    "model": model,
                    "temperature": 0,
                    "max_tokens": a.reasoning_cap,
                    "reasoning_effort": effort,
                    "messages": [{"role": "user", "content": nonce() + q}],
                }
            )
        except urllib.error.HTTPError as e:
            row(
                results,
                "reasoning",
                effort=effort,
                error=f"HTTP {e.code}: {e.read()[:200].decode(errors='replace')}",
            )
            continue
        row(
            results,
            "reasoning",
            effort=effort,
            completion_tokens=r["usage"]["completion_tokens"],
            finish=r["finish"],
            runaway=r["finish"] == "length",
            correct="0.05" in r["text"],
        )


def niah(c, model, a, results):
    for n in a.niah:
        for depth in (0.1, 0.5, 0.9):
            code = f"{random.randrange(10**6):06d}"
            lines = filler(n).splitlines(keepends=True)
            lines.insert(int(len(lines) * depth), f"The vault passcode is {code}.\n")
            msg = (
                nonce()
                + "".join(lines)
                + "\nWhat is the vault passcode? Answer with the digits only."
            )
            try:
                r = c.chat(
                    {
                        "model": model,
                        "temperature": 0,
                        "max_tokens": 2048,
                        "reasoning_effort": "low",
                        "messages": [{"role": "user", "content": msg}],
                    }
                )
            except urllib.error.HTTPError as e:
                row(
                    results,
                    "niah",
                    target=n,
                    depth=depth,
                    error=f"HTTP {e.code}: {e.read()[:200].decode(errors='replace')}",
                )
                continue
            row(
                results,
                "niah",
                target=n,
                depth=depth,
                prompt_tokens=r["usage"]["prompt_tokens"],
                found=code in r["text"],
                ttft_s=r["ttft"],
            )


def ints(s):
    return [int(x) for x in s.split(",") if x]


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--base", required=True)
    p.add_argument("--key")
    p.add_argument("--model", help="default: the first id from /v1/models")
    p.add_argument("--only", default="perf,tools,reasoning,niah")
    p.add_argument("--prefill", type=ints, default=[4096, 32768])
    p.add_argument("--concurrency", type=ints, default=[1, 2, 4])
    p.add_argument("--niah", type=ints, default=[32768, 131072])
    p.add_argument("--reasoning-cap", type=int, default=32768)
    p.add_argument(
        "--effort",
        choices=["send", "omit"],
        default="send",
        help="omit: never send reasoning_effort",
    )
    p.add_argument("--replay")
    p.add_argument("--timeout", type=float, default=1800)
    p.add_argument("--out")
    a = p.parse_args()
    c = Client(a.base, a.key, a.timeout, omit_effort=a.effort == "omit")
    model = a.model or c.model()
    results = [
        {
            "section": "meta",
            "base": a.base,
            "model": model,
            "time": time.strftime("%FT%T%z"),
        }
    ]
    print(f"meta base={a.base} model={model}", flush=True)
    sections = {"perf": perf, "tools": tools, "reasoning": reasoning, "niah": niah}
    for name in a.only.split(","):
        try:
            sections[name](c, model, a, results)
        except urllib.error.HTTPError as e:
            row(
                results,
                name,
                error=f"HTTP {e.code}: {e.read()[:200].decode(errors='replace')}",
            )
    if a.out:
        with open(a.out, "w") as f:
            json.dump(results, f, indent=1)


if __name__ == "__main__":
    sys.exit(main())

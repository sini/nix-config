"""Prune CNPG volumeSnapshot backups to the newest KEEP completed per schedule.

CNPG applies no retention to volumeSnapshot backups, and each one's
VolumeSnapshot is a Longhorn NAS backup (class deletionPolicy Delete), so they
accumulate forever. Per (namespace, cnpg.io/scheduled-backup), keep the newest
KEEP completed Backups; delete everything older, VolumeSnapshot first (which
removes the NAS backup), then the Backup. Manual (unscheduled) backups are
never touched.

    python3 prune-backups.py --self-test
"""

import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from collections import defaultdict

SCHEDULE_LABEL = "cnpg.io/scheduled-backup"


def plan(backups, keep):
    """Names of Backups to delete, as (namespace, name) pairs, oldest first."""
    groups = defaultdict(list)
    for b in backups:
        meta = b["metadata"]
        schedule = meta.get("labels", {}).get(SCHEDULE_LABEL)
        if schedule:
            groups[(meta["namespace"], schedule)].append(b)
    doomed = []
    for items in groups.values():
        items.sort(key=lambda b: b["metadata"]["creationTimestamp"], reverse=True)
        completed = [
            b for b in items if b.get("status", {}).get("phase") == "completed"
        ]
        if len(completed) < keep:
            continue
        cutoff = completed[keep - 1]["metadata"]["creationTimestamp"]
        doomed += [
            (b["metadata"]["namespace"], b["metadata"]["name"])
            for b in items
            if b["metadata"]["creationTimestamp"] < cutoff
        ]
    return sorted(doomed)


def self_test():
    def b(ns, name, ts, phase="completed", schedule="nightly"):
        labels = {SCHEDULE_LABEL: schedule} if schedule else {}
        return {
            "metadata": {
                "namespace": ns,
                "name": name,
                "creationTimestamp": ts,
                "labels": labels,
            },
            "status": {"phase": phase},
        }

    backups = [b("a", f"n{d}", f"2026-10-0{d}T04:00:00Z") for d in range(1, 10)]
    backups += [
        b("a", "failed-old", "2026-09-30T04:00:00Z", phase="failed"),
        b("a", "manual", "2026-09-01T00:00:00Z", schedule=None),
        b("c", "few1", "2026-10-01T04:00:00Z"),
        b("c", "few2", "2026-10-02T04:00:00Z"),
    ]
    got = plan(backups, 7)
    want = [("a", "failed-old"), ("a", "n1"), ("a", "n2")]
    assert got == want, got
    # A failed run never counts towards the kept set.
    backups.append(b("a", "n10-failed", "2026-10-10T04:00:00Z", phase="failed"))
    assert plan(backups, 7) == want, plan(backups, 7)
    print("ok")


class Api:
    SA = "/var/run/secrets/kubernetes.io/serviceaccount"

    def __init__(self):
        host = os.environ["KUBERNETES_SERVICE_HOST"]
        port = os.environ["KUBERNETES_SERVICE_PORT"]
        self.base = f"https://{host}:{port}"
        with open(f"{self.SA}/token") as f:
            self.token = f.read().strip()
        self.ctx = ssl.create_default_context(cafile=f"{self.SA}/ca.crt")

    def call(self, method, path):
        req = urllib.request.Request(
            self.base + path,
            method=method,
            headers={"Authorization": f"Bearer {self.token}"},
        )
        try:
            with urllib.request.urlopen(req, context=self.ctx) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            if method == "DELETE" and e.code == 404:
                return None
            raise


def main():
    keep = int(os.environ["KEEP"])
    api = Api()
    backups = api.call("GET", "/apis/postgresql.cnpg.io/v1/backups")["items"]
    doomed = plan(backups, keep)
    for ns, name in doomed:
        snaps = api.call(
            "GET",
            f"/apis/snapshot.storage.k8s.io/v1/namespaces/{ns}/volumesnapshots"
            f"?labelSelector=cnpg.io%2FbackupName%3D{name}",
        )["items"]
        for s in snaps:
            api.call(
                "DELETE",
                f"/apis/snapshot.storage.k8s.io/v1/namespaces/{ns}/volumesnapshots/{s['metadata']['name']}",
            )
        api.call(
            "DELETE", f"/apis/postgresql.cnpg.io/v1/namespaces/{ns}/backups/{name}"
        )
        print(f"pruned {ns}/{name} ({len(snaps)} snapshot(s))", flush=True)
    print(f"kept newest {keep} per schedule; pruned {len(doomed)}")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        main()

# Symbolic Short-Term Memory Topo-Graph — Curatare

> **Memory Category:** TencentDB Symbolic Graph Asset
> **Scope:** Runtime state transitions for scans, dated-trash batches, and batch restoration.

---

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Scanning : startScan(section)
    Scanning --> ReadyToReview : scanCompleted(findings)
    Scanning --> Failed : errorOccurred
    ReadyToReview --> CheckingProcesses : moveSelectedToDatedTrash()
    CheckingProcesses --> BlockedByRunningApp : pgrepFoundActiveOwner
    BlockedByRunningApp --> ReadyToReview : userDismissesOrClosesApp
    CheckingProcesses --> MovingToDatedTrash : allOwnersClosed
    MovingToDatedTrash --> CompletedInTrash : manifestRecorded
    CompletedInTrash --> Restored : restoreBatch(batchID)
    Restored --> ReadyToReview
```

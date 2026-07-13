import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from albertlm.checkpoint import save_checkpoint
import torch
from torch.utils.data import Dataset, DataLoader

from albertlm.config import load_config
from albertlm.model import AlbertLM


class ToyDataset(Dataset):

    def __init__(
        self,
        vocab_size,
        seq_len,
        size
    ):
        self.vocab_size = vocab_size
        self.seq_len = seq_len
        self.size = size


    def __len__(self):
        return self.size


    def __getitem__(self, idx):

        start = torch.randint(
            0,
            self.vocab_size - self.seq_len - 1,
            (1,)
        ).item()


        tokens = torch.arange(
            start,
            start + self.seq_len
        )

        return tokens



def write_status(
    status,
    step,
    loss,
    checkpoint=None
):

    data = {
        "time": datetime.now().isoformat(),
        "status": status,
        "step": step,
        "loss": float(loss),
        "checkpoint": checkpoint,
        "gpu": "RTX 5090D v2"
    }


    Path("logs").mkdir(
        exist_ok=True
    )


    with open(
        "logs/status.json",
        "w"
    ) as f:
        json.dump(
            data,
            f,
            indent=2
        )


def gradient_norm(model):

    squared_norm = 0.0

    for parameter in model.parameters():
        if parameter.grad is not None:
            norm = parameter.grad.detach().float().norm(2).item()
            squared_norm += norm * norm

    return squared_norm ** 0.5


def append_metrics(
    step,
    tokens_seen,
    train_loss,
    learning_rate,
    grad_norm,
    tokens_per_second
):

    Path("logs").mkdir(exist_ok=True)

    data = {
        "schema_version": 1,
        "step": int(step),
        "tokens_seen": int(tokens_seen),
        "train_loss": float(train_loss),
        "learning_rate": float(learning_rate),
        "grad_norm": float(grad_norm),
        "tokens_per_second": float(tokens_per_second),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

    with open("logs/metrics.jsonl", "a", buffering=1) as metrics_file:
        metrics_file.write(json.dumps(data) + "\n")



def main():

    device="cuda"

    config = load_config(
        "configs/model/albertlm-125m.yaml"
    )


    model = AlbertLM(config)

    model = (
        model
        .cuda()
        .bfloat16()
    )


    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=3e-4,
        weight_decay=0.1
    )


    dataset = ToyDataset(
        config.vocab_size,
        128,
        10000
    )


    loader = DataLoader(
        dataset,
        batch_size=4,
        shuffle=True
    )


    model.train()

    metrics_every = max(
        1,
        int(os.environ.get("METRICS_EVERY_N_STEPS", "10"))
    )
    tokens_seen = 0
    metrics_window_tokens = 0
    metrics_window_started = time.perf_counter()

    for step, batch in enumerate(loader):

        batch = batch.cuda()
        batch_tokens = batch.numel()
        tokens_seen += batch_tokens
        metrics_window_tokens += batch_tokens


        out = model(
            batch,
            labels=batch
        )

        loss = out["loss"]


        optimizer.zero_grad()

        loss.backward()

        optimizer.step()


        if step % metrics_every == 0:

            torch.cuda.synchronize()
            elapsed = max(
                time.perf_counter() - metrics_window_started,
                1e-9
            )
            tokens_per_second = metrics_window_tokens / elapsed
            current_grad_norm = gradient_norm(model)
            learning_rate = optimizer.param_groups[0]["lr"]

            append_metrics(
                step,
                tokens_seen,
                loss.item(),
                learning_rate,
                current_grad_norm,
                tokens_per_second
            )

            metrics_window_tokens = 0
            metrics_window_started = time.perf_counter()

            print(
                f"step {step} loss {loss.item():.4f} "
                f"lr {learning_rate:.6g} "
                f"tokens/s {tokens_per_second:.1f}"
            )

            write_status(
                "training",
                step,
                loss.item()
            )


        if step % 100 == 0 and step > 0:

            checkpoint_path = (
                f"checkpoints/step_{step}.pt"
            )

            save_checkpoint(
                checkpoint_path,
                model,
                optimizer,
                step
            )

            write_status(
                "training",
                step,
                loss.item(),
                checkpoint_path
            )

            print(
                f"checkpoint saved: step {step}"
            )


        if step >= 1000000:
            break


if __name__=="__main__":
    main()

export class DeferredStorageWriter<T> {
  private readonly delayMs: number;
  private readonly write: (value: T) => void;
  private pending: T | null = null;
  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(write: (value: T) => void, delayMs = 300) {
    this.write = write;
    this.delayMs = delayMs;
  }

  enqueue(value: T): void {
    this.pending = value;
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = null;
      this.flush();
    }, this.delayMs);
  }

  flush(): void {
    if (this.pending === null) {
      return;
    }
    const value = this.pending;
    this.pending = null;
    this.write(value);
  }

  dispose(flush = true): void {
    this.clearTimer();
    if (flush) {
      this.flush();
    } else {
      this.pending = null;
    }
  }

  private clearTimer(): void {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }
}

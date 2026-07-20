export interface SharedMediaThumbnailTarget {
  readonly thumbFileId: number;
  thumbUri: string;
}

export type SharedMediaThumbnailLoader = (fileId: number) => Promise<string>;
export type SharedMediaThumbnailFailureReporter = (fileId: number, reason: string) => void;

class SharedMediaThumbnailRequest {
  readonly fileId: number;
  readonly targets: SharedMediaThumbnailTarget[] = [];
  isQueued: boolean = true;
  isRunning: boolean = false;
  isFinished: boolean = false;

  constructor(fileId: number) {
    this.fileId = fileId;
  }
}

// Keeps TDLib pressure bounded while allowing a newly visible Grid/List range
// to jump ahead of off-screen background work.
export class SharedMediaThumbnailCoordinator {
  private readonly loader: SharedMediaThumbnailLoader;
  private readonly reportFailure: SharedMediaThumbnailFailureReporter;
  private readonly maxConcurrent: number;
  private readonly requests: Map<number, SharedMediaThumbnailRequest> = new Map();
  private pendingFileIds: number[] = [];
  private activeCount: number = 0;
  private cancelled: boolean = false;

  constructor(loader: SharedMediaThumbnailLoader, reportFailure: SharedMediaThumbnailFailureReporter,
    maxConcurrent: number = 2) {
    this.loader = loader;
    this.reportFailure = reportFailure;
    this.maxConcurrent = Math.max(1, Math.floor(maxConcurrent));
  }

  enqueue(targets: SharedMediaThumbnailTarget[]): void {
    if (this.cancelled) {
      return;
    }
    for (let i = 0; i < targets.length; i++) {
      this.registerTarget(targets[i]);
    }
    this.pump();
  }

  prioritizeRange(targets: SharedMediaThumbnailTarget[], first: number, last: number): void {
    if (this.cancelled || targets.length === 0) {
      return;
    }
    const start = Math.max(0, Math.min(first, targets.length - 1));
    const end = Math.max(start, Math.min(last, targets.length - 1));
    const priorityIds: number[] = [];
    for (let i = start; i <= end; i++) {
      const request = this.registerTarget(targets[i]);
      const fileId = targets[i].thumbFileId;
      if (request !== undefined && request.isQueued && priorityIds.indexOf(fileId) < 0) {
        priorityIds.push(fileId);
      }
    }
    if (priorityIds.length === 0) {
      return;
    }
    const backgroundIds: number[] = [];
    for (let i = 0; i < this.pendingFileIds.length; i++) {
      const fileId = this.pendingFileIds[i];
      if (priorityIds.indexOf(fileId) < 0) {
        backgroundIds.push(fileId);
      }
    }
    this.pendingFileIds = priorityIds.concat(backgroundIds);
    this.pump();
  }

  private registerTarget(target: SharedMediaThumbnailTarget): SharedMediaThumbnailRequest | undefined {
    if (target.thumbFileId <= 0 || target.thumbUri.length > 0) {
      return undefined;
    }
    let request = this.requests.get(target.thumbFileId);
    if (request === undefined) {
      request = new SharedMediaThumbnailRequest(target.thumbFileId);
      this.requests.set(target.thumbFileId, request);
      this.pendingFileIds.push(target.thumbFileId);
    }
    if (request.targets.indexOf(target) < 0) {
      request.targets.push(target);
    }
    return request;
  }

  cancel(): void {
    this.cancelled = true;
    this.pendingFileIds = [];
  }

  private pump(): void {
    while (!this.cancelled && this.activeCount < this.maxConcurrent && this.pendingFileIds.length > 0) {
      const fileId = this.pendingFileIds.shift();
      if (fileId === undefined) {
        return;
      }
      const request = this.requests.get(fileId);
      if (request === undefined || !request.isQueued) {
        continue;
      }
      request.isQueued = false;
      request.isRunning = true;
      this.activeCount++;
      this.loadRequest(request);
    }
  }

  private async loadRequest(request: SharedMediaThumbnailRequest): Promise<void> {
    let uri = '';
    let failureReason = '';
    try {
      uri = await this.loader(request.fileId);
    } catch (error) {
      failureReason = String(error);
    }

    if (!this.cancelled) {
      if (uri.length > 0) {
        for (let i = 0; i < request.targets.length; i++) {
          request.targets[i].thumbUri = uri;
        }
      } else if (failureReason.length > 0) {
        this.reportFailure(request.fileId, failureReason);
      }
    }

    request.isRunning = false;
    request.isFinished = true;
    this.activeCount--;
    this.pump();
  }
}

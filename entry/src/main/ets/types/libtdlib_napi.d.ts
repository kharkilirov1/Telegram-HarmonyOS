declare module 'libtdlib_napi.so' {
  export interface ReceiveLoopStats {
    epoch: number;
    status: number;
    outstandingBatches: number;
    outstandingBytes: number;
    nativeQueuedBatches: number;
    nativeQueuedBytes: number;
    admittedBatches: number;
    admittedBytes: number;
    builderBytes: number;
    lookaheadBytes: number;
    pendingNotifications: number;
    peakOutstandingBatches: number;
    peakOutstandingBytes: number;
    peakBuilderBytes: number;
    peakLookaheadBytes: number;
    peakPendingNotifications: number;
    marshalRetries: number;
    notifyRetries: number;
    producerExited: boolean;
    producerJoined: boolean;
    tsfnFinalized: boolean;
  }
  export interface TdlibNapiModule {
    createClient(): number;
    send(clientId: number, requestJson: string): void;
    receive(timeoutSeconds: number): string | null;
    execute(requestJson: string): string | null;
    startReceiveLoop(callback: (json: string, epoch: number, batchId: number, utf8Bytes: number) => boolean): number;
    ackReceiveBatch(epoch: number, batchId: number): boolean;
    getReceiveLoopStatus(): number;
    getReceiveLoopStats(): ReceiveLoopStats;
    /** Resolves only after producer join AND TSFN finalization. Incomplete cleanup retains ownership;
     * rejected control work permits a stop retry, without guaranteeing completion. Start remains blocked
     * until retirement; a terminal fault stays observable until the next successful start. */
    stopReceiveLoop(): Promise<void>;
    /** Returns JSON: { mode: "REAL", tdlibDir: string, soname: string } */
    getTdlibInfo(): string;
  }

  const tdlib: TdlibNapiModule;
  export default tdlib;
}

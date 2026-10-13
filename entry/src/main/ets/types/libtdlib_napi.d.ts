declare module 'libtdlib_napi.so' {
  export interface TdlibNapiModule {
    createClient(): number;
    send(clientId: number, requestJson: string): void;
    receive(timeoutSeconds: number): string | null;
    execute(requestJson: string): string | null;
    startReceiveLoop(callback: (responseJson: string) => void): void;
    /** Resolves after the receive worker has stopped; rejection requires a stop retry before start. */
    stopReceiveLoop(): Promise<void>;
    /** Returns JSON: { mode: "REAL", tdlibDir: string, soname: string } */
    getTdlibInfo(): string;
  }

  const tdlib: TdlibNapiModule;
  export default tdlib;
}

declare module 'libtdlib_napi.so' {
  export interface TdlibNapiModule {
    createClient(): number;
    send(clientId: number, requestJson: string): void;
    receive(timeoutSeconds: number): string | null;
    execute(requestJson: string): string | null;
    startReceiveLoop(callback: (responseJson: string) => void): void;
    stopReceiveLoop(): void;
    /** Returns JSON: { mode: "REAL", tdlibDir: string, soname: string } */
    getTdlibInfo(): string;
  }

  const tdlib: TdlibNapiModule;
  export default tdlib;
}

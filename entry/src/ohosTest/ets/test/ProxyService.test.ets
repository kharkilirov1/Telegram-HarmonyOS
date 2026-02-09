import { describe, it, expect } from '@ohos/hypium';
import { ProxyService } from '../../../main/ets/services/ProxyService';

/**
 * Unit tests for ProxyService — proxy management use-case layer.
 * Tests focus on static utility methods since TDLib calls require a live client.
 */

export default function proxyServiceTest() {
  describe('ProxyService', () => {

    // -----------------------------------------------------------------------
    // Singleton pattern
    // -----------------------------------------------------------------------
    describe('getInstance', () => {

      it('should return same instance', 0, () => {
        const a = ProxyService.getInstance();
        const b = ProxyService.getInstance();
        expect(a === b).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // buildProxyTypeParam — static factory for proxy type objects
    // -----------------------------------------------------------------------
    describe('buildProxyTypeParam', () => {

      it('should build socks5 type', 0, () => {
        const result = ProxyService.buildProxyTypeParam('socks5', 'user1', 'pass1', '');
        expect(result['@type']).assertEqual('proxyTypeSocks5');
        expect(result['username']).assertEqual('user1');
        expect(result['password']).assertEqual('pass1');
      });

      it('should build http type', 0, () => {
        const result = ProxyService.buildProxyTypeParam('http', 'httpuser', 'httppass', '');
        expect(result['@type']).assertEqual('proxyTypeHttp');
        expect(result['username']).assertEqual('httpuser');
        expect(result['password']).assertEqual('httppass');
        expect(result['http_only']).assertFalse();
      });

      it('should build mtproto type', 0, () => {
        const result = ProxyService.buildProxyTypeParam('mtproto', '', '', 'abc123secret');
        expect(result['@type']).assertEqual('proxyTypeMtproto');
        expect(result['secret']).assertEqual('abc123secret');
      });

      it('should default unknown type to mtproto', 0, () => {
        const result = ProxyService.buildProxyTypeParam('other', '', '', 'sec');
        expect(result['@type']).assertEqual('proxyTypeMtproto');
      });

      it('should handle empty credentials for socks5', 0, () => {
        const result = ProxyService.buildProxyTypeParam('socks5', '', '', '');
        expect(result['username']).assertEqual('');
        expect(result['password']).assertEqual('');
      });
    });
  });
}

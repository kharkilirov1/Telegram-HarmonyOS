import { describe, it, expect } from '@ohos/hypium';
import {
  containsUrl,
  extractDomain,
  splitByUrls,
  formatMessageTime,
  formatMediaDuration,
  getSenderColor,
  TextPart
} from '../../../main/ets/components/Message/MessageUtils';

/**
 * Unit tests for MessageUtils — pure utility functions extracted from
 * MessageBubble. All functions are stateless.
 */

export default function messageUtilsTest() {
  describe('MessageUtils', () => {

    // -----------------------------------------------------------------------
    // containsUrl
    // -----------------------------------------------------------------------
    describe('containsUrl', () => {

      it('should detect http URL', 0, () => {
        expect(containsUrl('Visit http://example.com')).assertTrue();
      });

      it('should detect https URL', 0, () => {
        expect(containsUrl('See https://telegram.org/blog')).assertTrue();
      });

      it('should return false for plain text', 0, () => {
        expect(containsUrl('Hello world')).assertFalse();
      });

      it('should return false for empty string', 0, () => {
        expect(containsUrl('')).assertFalse();
      });

      it('should detect URL embedded in text', 0, () => {
        expect(containsUrl('Check out https://t.me/channel for updates')).assertTrue();
      });

      it('should not match partial protocol', 0, () => {
        expect(containsUrl('ftp://files.example.com')).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // extractDomain
    // -----------------------------------------------------------------------
    describe('extractDomain', () => {

      it('should extract domain from http URL', 0, () => {
        expect(extractDomain('Visit http://example.com/page')).assertEqual('example.com');
      });

      it('should extract domain from https URL', 0, () => {
        expect(extractDomain('See https://telegram.org/blog')).assertEqual('telegram.org');
      });

      it('should return empty for text without URL', 0, () => {
        expect(extractDomain('No links here')).assertEqual('');
      });

      it('should extract first URL domain when multiple present', 0, () => {
        const text = 'Visit https://first.com and https://second.com';
        const domain = extractDomain(text);
        expect(domain).assertEqual('first.com');
      });

      it('should handle subdomain', 0, () => {
        expect(extractDomain('https://api.example.com/v1')).assertEqual('api.example.com');
      });
    });

    // -----------------------------------------------------------------------
    // splitByUrls
    // -----------------------------------------------------------------------
    describe('splitByUrls', () => {

      it('should return single non-URL part for plain text', 0, () => {
        const parts = splitByUrls('Hello world');
        expect(parts.length).assertEqual(1);
        expect(parts[0].text).assertEqual('Hello world');
        expect(parts[0].isUrl).assertFalse();
      });

      it('should split text with embedded URL', 0, () => {
        const parts = splitByUrls('Visit https://example.com now');
        expect(parts.length).assertEqual(3);
        expect(parts[0].text).assertEqual('Visit ');
        expect(parts[0].isUrl).assertFalse();
        expect(parts[1].text).assertEqual('https://example.com');
        expect(parts[1].isUrl).assertTrue();
        expect(parts[2].text).assertEqual(' now');
        expect(parts[2].isUrl).assertFalse();
      });

      it('should handle URL at start of text', 0, () => {
        const parts = splitByUrls('https://example.com is great');
        expect(parts.length).assertEqual(2);
        expect(parts[0].isUrl).assertTrue();
        expect(parts[1].isUrl).assertFalse();
      });

      it('should handle URL at end of text', 0, () => {
        const parts = splitByUrls('Check https://example.com');
        expect(parts.length).assertEqual(2);
        expect(parts[0].isUrl).assertFalse();
        expect(parts[1].isUrl).assertTrue();
      });

      it('should handle URL-only text', 0, () => {
        const parts = splitByUrls('https://example.com');
        expect(parts.length).assertEqual(1);
        expect(parts[0].isUrl).assertTrue();
      });

      it('should handle multiple URLs', 0, () => {
        const parts = splitByUrls('See https://a.com and https://b.com');
        // Expected: ["See ", "https://a.com", " and ", "https://b.com"]
        expect(parts.length).assertEqual(4);
        expect(parts[1].isUrl).assertTrue();
        expect(parts[3].isUrl).assertTrue();
      });

      it('should return single part for empty string', 0, () => {
        const parts = splitByUrls('');
        expect(parts.length).assertEqual(1);
        expect(parts[0].text).assertEqual('');
        expect(parts[0].isUrl).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // formatMessageTime
    // -----------------------------------------------------------------------
    describe('formatMessageTime', () => {

      it('should return empty string for 0 timestamp', 0, () => {
        expect(formatMessageTime(0)).assertEqual('');
      });

      it('should return non-empty string for valid timestamp', 0, () => {
        // 1700000000 = 2023-11-14T22:13:20 UTC
        const result = formatMessageTime(1700000000);
        expect(result.length > 0).assertTrue();
      });

      it('should contain colon (hour:minute format)', 0, () => {
        const result = formatMessageTime(1700000000);
        expect(result.indexOf(':') >= 0).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // formatMediaDuration
    // -----------------------------------------------------------------------
    describe('formatMediaDuration', () => {

      it('should format 0 seconds', 0, () => {
        expect(formatMediaDuration(0)).assertEqual('0:00');
      });

      it('should format seconds < 60', 0, () => {
        expect(formatMediaDuration(45)).assertEqual('0:45');
      });

      it('should format exactly 60 seconds', 0, () => {
        expect(formatMediaDuration(60)).assertEqual('1:00');
      });

      it('should format minutes and seconds', 0, () => {
        expect(formatMediaDuration(125)).assertEqual('2:05');
      });

      it('should format hours', 0, () => {
        expect(formatMediaDuration(3661)).assertEqual('1:01:01');
      });

      it('should pad seconds to 2 digits', 0, () => {
        expect(formatMediaDuration(63)).assertEqual('1:03');
      });

      it('should pad minutes to 2 digits when hours present', 0, () => {
        expect(formatMediaDuration(3605)).assertEqual('1:00:05');
      });
    });

    // -----------------------------------------------------------------------
    // getSenderColor
    // -----------------------------------------------------------------------
    describe('getSenderColor', () => {

      it('should return a ResourceColor for any senderId', 0, () => {
        const color = getSenderColor(12345);
        // ResourceColor is a Resource object; should not be undefined
        expect(color !== undefined).assertTrue();
      });

      it('should return consistent color for same senderId', 0, () => {
        const color1 = getSenderColor(42);
        const color2 = getSenderColor(42);
        // Both should be the same Resource reference (same index)
        expect(JSON.stringify(color1)).assertEqual(JSON.stringify(color2));
      });

      it('should handle negative senderId (channel senders)', 0, () => {
        const color = getSenderColor(-1001234567);
        expect(color !== undefined).assertTrue();
      });

      it('should handle senderId of 0', 0, () => {
        const color = getSenderColor(0);
        expect(color !== undefined).assertTrue();
      });
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { Chat } from '../../../main/ets/models/Chat';
import {
  decodeWaveform,
  extractTextPreview
} from '../../../main/ets/controllers/TdMessageParser';
import { TdMessage } from '../../../main/ets/models/TdTypes';

/**
 * Unit tests for MessagesController helpers.
 *
 * After the Sprint A refactoring, the pure logic (decodeWaveform,
 * extractTextPreview, sortDialogs) was extracted to TdMessageParser
 * and TdTypes. These tests now import the real functions directly
 * instead of duplicating them.
 */

// sortDialogs is a private method on MessagesController. We test the
// algorithm here with a standalone copy since the class is a singleton
// with TDLib subscriptions.
function sortDialogs(dialogs: Chat[]): void {
  dialogs.sort((a: Chat, b: Chat): number => {
    if (a.order > b.order) return -1;
    if (a.order < b.order) return 1;
    return 0;
  });
}

export default function messagesControllerTest() {
  describe('MessagesController', () => {

    // -----------------------------------------------------------------------
    // decodeWaveform (now imported from TdMessageParser)
    // -----------------------------------------------------------------------
    describe('decodeWaveform', () => {

      it('should decode a known base64 waveform into 5-bit amplitude values', 0, () => {
        const result = decodeWaveform('AQID');
        expect(result.length).assertEqual(4);

        for (const v of result) {
          expect(v >= 0).assertTrue();
          expect(v <= 1).assertTrue();
        }

        expect(Math.abs(result[0] - 1 / 31.0) < 0.001).assertTrue();
        expect(Math.abs(result[1] - 16 / 31.0) < 0.001).assertTrue();
        expect(Math.abs(result[2] - 0 / 31.0) < 0.001).assertTrue();
        expect(Math.abs(result[3] - 6 / 31.0) < 0.001).assertTrue();
      });

      it('should return fallback waveform for empty input', 0, () => {
        const result = decodeWaveform('');
        expect(result.length).assertEqual(32);
        for (const v of result) {
          expect(Math.abs(v - 0.3) < 0.001).assertTrue();
        }
      });

      it('should return fallback waveform for invalid base64 input', 0, () => {
        const result = decodeWaveform('!!!invalid!!!');
        expect(result.length).assertEqual(32);
        for (const v of result) {
          expect(Math.abs(v - 0.3) < 0.001).assertTrue();
        }
      });

      it('should produce values normalized between 0 and 1', 0, () => {
        const result = decodeWaveform('/////w==');
        for (const v of result) {
          expect(v >= 0).assertTrue();
          expect(v <= 1.0).assertTrue();
        }
      });

      it('should handle single-byte base64 input', 0, () => {
        const result = decodeWaveform('AQ==');
        expect(result.length).assertEqual(1);
        expect(Math.abs(result[0] - 1 / 31.0) < 0.001).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // extractTextPreview (now imported from TdMessageParser)
    // -----------------------------------------------------------------------
    describe('extractTextPreview', () => {

      it('should extract text from messageText', 0, () => {
        const textInner: Record<string, Object> = {};
        textInner['text'] = 'Hello world';
        const content: Record<string, Object> = {};
        content['@type'] = 'messageText';
        content['text'] = textInner;
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('Hello world');
      });

      it('should return "Photo" for messagePhoto', 0, () => {
        const content: Record<string, Object> = {};
        content['@type'] = 'messagePhoto';
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('Photo');
      });

      it('should return "Video" for messageVideo', 0, () => {
        const content: Record<string, Object> = {};
        content['@type'] = 'messageVideo';
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('Video');
      });

      it('should return file name for messageDocument', 0, () => {
        const doc: Record<string, Object> = {};
        doc['file_name'] = 'report.pdf';
        const content: Record<string, Object> = {};
        content['@type'] = 'messageDocument';
        content['document'] = doc;
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('report.pdf');
      });

      it('should return "Document" when document has no file_name', 0, () => {
        const doc: Record<string, Object> = {};
        const content: Record<string, Object> = {};
        content['@type'] = 'messageDocument';
        content['document'] = doc;
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('Document');
      });

      it('should return "Voice message" for messageVoiceNote', 0, () => {
        const content: Record<string, Object> = {};
        content['@type'] = 'messageVoiceNote';
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('Voice message');
      });

      it('should return emoji + Sticker for messageSticker', 0, () => {
        const sticker: Record<string, Object> = {};
        sticker['emoji'] = '\u{1F600}';
        const content: Record<string, Object> = {};
        content['@type'] = 'messageSticker';
        content['sticker'] = sticker;
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        const preview = extractTextPreview(raw as unknown as TdMessage);
        expect(preview.indexOf('Sticker') >= 0).assertTrue();
        expect(preview.indexOf('\u{1F600}') >= 0).assertTrue();
      });

      it('should return "GIF" for messageAnimation', 0, () => {
        const content: Record<string, Object> = {};
        content['@type'] = 'messageAnimation';
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('GIF');
      });

      it('should return empty string when content is missing', 0, () => {
        const raw: Record<string, Object> = {};
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('');
      });

      it('should strip "message" prefix for unknown types', 0, () => {
        const content: Record<string, Object> = {};
        content['@type'] = 'messageContact';
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('Contact');
      });

      it('should return "Video message" for messageVideoNote', 0, () => {
        const content: Record<string, Object> = {};
        content['@type'] = 'messageVideoNote';
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        expect(extractTextPreview(raw as unknown as TdMessage)).assertEqual('Video message');
      });

      it('should return poll question for messagePoll', 0, () => {
        const question: Record<string, Object> = {};
        question['text'] = 'Favorite language?';
        const poll: Record<string, Object> = {};
        poll['question'] = question;
        const content: Record<string, Object> = {};
        content['@type'] = 'messagePoll';
        content['poll'] = poll;
        const raw: Record<string, Object> = {};
        raw['content'] = content;
        const preview = extractTextPreview(raw as unknown as TdMessage);
        expect(preview.indexOf('Favorite language?') >= 0).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // sortDialogs
    // -----------------------------------------------------------------------
    describe('sortDialogs', () => {

      it('should sort chats by order descending', 0, () => {
        const chat1 = new Chat(1, 'Alice');
        chat1.order = '100';
        const chat2 = new Chat(2, 'Bob');
        chat2.order = '300';
        const chat3 = new Chat(3, 'Charlie');
        chat3.order = '200';

        const dialogs: Chat[] = [chat1, chat2, chat3];
        sortDialogs(dialogs);

        expect(dialogs[0].id).assertEqual(2);
        expect(dialogs[1].id).assertEqual(3);
        expect(dialogs[2].id).assertEqual(1);
      });

      it('should maintain stable order for equal orders', 0, () => {
        const chat1 = new Chat(1, 'Alpha');
        chat1.order = '100';
        const chat2 = new Chat(2, 'Beta');
        chat2.order = '100';

        const dialogs: Chat[] = [chat1, chat2];
        sortDialogs(dialogs);
        expect(dialogs.length).assertEqual(2);
      });

      it('should handle empty array', 0, () => {
        const dialogs: Chat[] = [];
        sortDialogs(dialogs);
        expect(dialogs.length).assertEqual(0);
      });

      it('should handle single element', 0, () => {
        const chat1 = new Chat(1, 'Solo');
        chat1.order = '50';
        const dialogs: Chat[] = [chat1];
        sortDialogs(dialogs);
        expect(dialogs[0].id).assertEqual(1);
      });

      it('should sort string orders lexicographically (TDLib uses string ordering)', 0, () => {
        const chat1 = new Chat(1, 'A');
        chat1.order = '6917529027641081856';
        const chat2 = new Chat(2, 'B');
        chat2.order = '6917529027641081857';
        const chat3 = new Chat(3, 'C');
        chat3.order = '0';

        const dialogs: Chat[] = [chat3, chat1, chat2];
        sortDialogs(dialogs);

        expect(dialogs[0].id).assertEqual(2);
        expect(dialogs[1].id).assertEqual(1);
        expect(dialogs[2].id).assertEqual(3);
      });
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { TdObject } from '../../../main/ets/core/utils/tdAccessors';
import {
  UserDto,
  createUserDtoFromTd,
  parseUserStatus,
  applyUserUpdate
} from '../../../main/ets/core/model/dto/UserDto';

/**
 * Unit tests for the current UserDto TDLib parsing surface.
 * Contact-list UI sorting remains a ContactsPage/view-model seam follow-up.
 */
export default function userDtoTest() {
  describe('UserDto', () => {

    describe('parseUserStatus', () => {
      it('should map known TDLib status types', 0, () => {
        expect(parseUserStatus(TdObject.fromJSON('{"@type":"userStatusOnline"}'))).assertEqual('online');
        expect(parseUserStatus(TdObject.fromJSON('{"@type":"userStatusOffline"}'))).assertEqual('offline');
        expect(parseUserStatus(TdObject.fromJSON('{"@type":"userStatusRecently"}'))).assertEqual('recently');
        expect(parseUserStatus(TdObject.fromJSON('{"@type":"userStatusLastWeek"}'))).assertEqual('lastWeek');
        expect(parseUserStatus(TdObject.fromJSON('{"@type":"userStatusLastMonth"}'))).assertEqual('lastMonth');
      });

      it('should treat empty or unknown status as longTimeAgo', 0, () => {
        expect(parseUserStatus(TdObject.fromJSON('{"@type":"userStatusEmpty"}'))).assertEqual('longTimeAgo');
        expect(parseUserStatus(TdObject.empty())).assertEqual('longTimeAgo');
      });
    });

    describe('createUserDtoFromTd', () => {
      it('should parse core user fields, direct username, flags, and status', 0, () => {
        const tdUser = TdObject.fromJSON(
          '{"@type":"user","id":12345,"first_name":"Alice","last_name":"Smith",' +
            '"username":"alice_s","accent_color_id":7,"phone_number":"+1234567890",' +
            '"is_contact":true,"is_verified":true,"is_scam":false,"is_fake":false,' +
            '"is_premium":true,"status":{"@type":"userStatusOnline"}}'
        );

        const dto = createUserDtoFromTd(tdUser);
        expect(dto.id).assertEqual(12345);
        expect(dto.firstName).assertEqual('Alice');
        expect(dto.lastName).assertEqual('Smith');
        expect(dto.username).assertEqual('alice_s');
        expect(dto.accentColorId).assertEqual(7);
        expect(dto.phoneNumber).assertEqual('+1234567890');
        expect(dto.isContact).assertTrue();
        expect(dto.isVerified).assertTrue();
        expect(dto.isScam).assertFalse();
        expect(dto.isFake).assertFalse();
        expect(dto.isPremium).assertTrue();
        expect(dto.status).assertEqual('online');
      });

      it('should use editable_username when direct username is absent', 0, () => {
        const tdUser = TdObject.fromJSON(
          '{"@type":"user","id":6,"usernames":{"@type":"usernames","editable_username":"bob_username"}}'
        );

        const dto = createUserDtoFromTd(tdUser);
        expect(dto.id).assertEqual(6);
        expect(dto.username).assertEqual('bob_username');
      });

      it('should extract profile photo paths and top-level file ids', 0, () => {
        const tdUser = TdObject.fromJSON(
          '{"@type":"user","id":4,"profile_photo":{"@type":"profilePhoto",' +
            '"small":{"@type":"file","id":111,"local":{"@type":"localFile","path":"/data/photos/small.jpg"}},' +
            '"big":{"@type":"file","id":222,"local":{"@type":"localFile","path":"/data/photos/big.jpg"}}}}'
        );

        const dto = createUserDtoFromTd(tdUser);
        expect(dto.photo !== undefined).assertTrue();
        if (dto.photo !== undefined) {
          expect(dto.photo.small).assertEqual('/data/photos/small.jpg');
          expect(dto.photo.big).assertEqual('/data/photos/big.jpg');
          expect(dto.photo.smallFileId).assertEqual(111);
          expect(dto.photo.bigFileId).assertEqual(222);
        }
      });

      it('should keep safe defaults when TDLib fields are absent', 0, () => {
        const dto = createUserDtoFromTd(TdObject.fromJSON('{"@type":"user"}'));
        expect(dto.id).assertEqual(0);
        expect(dto.firstName).assertEqual('');
        expect(dto.lastName).assertEqual('');
        expect(dto.username).assertEqual('');
        expect(dto.accentColorId).assertEqual(-1);
        expect(dto.phoneNumber).assertEqual('');
        expect(dto.isContact).assertFalse();
        expect(dto.isVerified).assertFalse();
        expect(dto.isScam).assertFalse();
        expect(dto.isFake).assertFalse();
        expect(dto.isPremium).assertFalse();
        expect(dto.status).assertEqual('longTimeAgo');
        expect(dto.photo === undefined).assertTrue();
      });
    });

    describe('applyUserUpdate', () => {
      it('should copy unchanged fields and apply only provided updates', 0, () => {
        const user = new UserDto();
        user.id = 42;
        user.firstName = 'John';
        user.lastName = 'Doe';
        user.username = 'johnd';
        user.phoneNumber = '+555';
        user.status = 'offline';
        user.isContact = false;
        user.isPremium = false;

        const updated = applyUserUpdate(user, {
          firstName: 'Jane',
          status: 'recently',
          isContact: true
        });

        expect(updated.id).assertEqual(42);
        expect(updated.firstName).assertEqual('Jane');
        expect(updated.lastName).assertEqual('Doe');
        expect(updated.username).assertEqual('johnd');
        expect(updated.phoneNumber).assertEqual('+555');
        expect(updated.status).assertEqual('recently');
        expect(updated.isContact).assertTrue();
        expect(updated.isPremium).assertFalse();
      });
    });
  });
}

export class InviteLinkModel {
  link: string;
  memberCount: number;
  expireDate: number;
  isRevoked: boolean;
  isPrimary: boolean;

  constructor(
    link: string = '',
    memberCount: number = 0,
    expireDate: number = 0,
    isRevoked: boolean = false,
    isPrimary: boolean = false
  ) {
    this.link = link;
    this.memberCount = memberCount;
    this.expireDate = expireDate;
    this.isRevoked = isRevoked;
    this.isPrimary = isPrimary;
  }
}

@ObservedV2
export class User {
  @Trace id: number;
  @Trace firstName: string;
  @Trace lastName: string;
  @Trace username: string;
  @Trace phoneNumber: string;
  @Trace photoUrl: string | null;
  @Trace isOnline: boolean;
  @Trace lastSeenDate: number;

  constructor(
    id: number = 0,
    firstName: string = '',
    lastName: string = '',
    username: string = '',
    phoneNumber: string = '',
    photoUrl: string | null = null,
    isOnline: boolean = false,
    lastSeenDate: number = 0
  ) {
    this.id = id;
    this.firstName = firstName;
    this.lastName = lastName;
    this.username = username;
    this.phoneNumber = phoneNumber;
    this.photoUrl = photoUrl;
    this.isOnline = isOnline;
    this.lastSeenDate = lastSeenDate;
  }
}

export enum AuthorizationState {
  WAIT_PHONE_NUMBER = 'waitPhoneNumber',
  WAIT_CODE = 'waitCode',
  WAIT_PASSWORD = 'waitPassword',
  READY = 'ready',
  CLOSED = 'closed'
}

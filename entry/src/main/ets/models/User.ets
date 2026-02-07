@Observed
export class User {
  id: number;
  firstName: string;
  lastName: string;
  username: string;
  phoneNumber: string;
  photoUrl: string | null;
  isOnline: boolean;
  lastSeenDate: number;

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

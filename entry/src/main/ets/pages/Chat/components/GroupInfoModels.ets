export class GroupInfoMember {
  userId: number;
  name: string;
  status: string;
  photoUrl: string | null;
  isAdmin: boolean;

  constructor(
    userId: number = 0,
    name: string = '',
    status: string = '',
    photoUrl: string | null = null,
    isAdmin: boolean = false
  ) {
    this.userId = userId;
    this.name = name;
    this.status = status;
    this.photoUrl = photoUrl;
    this.isAdmin = isAdmin;
  }
}

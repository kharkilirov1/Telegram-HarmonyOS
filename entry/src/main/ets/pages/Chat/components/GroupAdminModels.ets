export interface GroupAdminMember {
  userId: number;
  name: string;
  role: string;
  photoUrl: string | null;
}

export interface GroupBannedMember {
  userId: number;
  name: string;
  bannedUntil: string;
}

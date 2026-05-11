// String constants for activity_logs.action values introduced by the staff-
// onboarding feature. activity_logs.action is a freeform text column (see
// 0001_initial.sql line 774) — these constants exist to keep call sites
// consistent across DAOs, screens, and tests, and to give a single grep
// target if we ever migrate to an enum.
//
// Naming: '<entity>.<verb>' (e.g. 'invite.accepted'). Lowercase, period-
// separated. New constants land here, not inline.

abstract final class ActivityActions {
  // Invites (Phase 1 / Phase 2 of the staff-onboarding rollout).
  static const inviteCreated = 'invite.created';
  static const inviteRevoked = 'invite.revoked';
  static const inviteResent = 'invite.resent';
  static const inviteExpired = 'invite.expired';
  static const inviteAccepted = 'invite.accepted';

  // Memberships (Phase 1 + Phase 5).
  static const memberCreated = 'member.created';
  static const memberSuspended = 'member.suspended';
  static const memberRemoved = 'member.removed';

  // Verification (Phase 3 + Phase 4).
  static const verificationUploaded = 'verification.uploaded';
  static const verificationApproved = 'verification.approved';
  static const verificationRejected = 'verification.rejected';

  // Recovery (Phase 5).
  static const pinResetAuthorized = 'pin.reset_authorized';
  static const sessionRevoked = 'session.revoked';
}

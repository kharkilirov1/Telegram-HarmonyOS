import { ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';

// One popup owns one request generation. Results are presentation snapshots only;
// target selection and send dispatch perform their own fresh eligibility checks.
export class ChatForwardSourceController {
  private generation: number = 0;

  cancel(): void {
    this.generation++;
  }

  load(useCase: ForwardMessagesUseCase, sourceChatId: number, messageIds: string[],
    isCurrent: () => boolean, onState: (state: string) => void): void {
    const generation = ++this.generation;
    const active = (): boolean => generation === this.generation && isCurrent();
    if (!active()) return;
    onState('loading');
    useCase.getSourceAvailability(sourceChatId, messageIds, active)
      .then((availability) => {
        if (!active()) return;
        onState(availability.ordinaryTargets || availability.secretTargets ? 'allowed' : 'denied');
      })
      .catch((_error: Object) => {
        if (!active()) return;
        onState('unavailable');
      });
  }
}

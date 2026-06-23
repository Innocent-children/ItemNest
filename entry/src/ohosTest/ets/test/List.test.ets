import appEventBusFlowTest from './AppEventBusFlow.test';
import abilityTest from './Ability.test';

export default function testsuite() {
  abilityTest();
  appEventBusFlowTest();
}

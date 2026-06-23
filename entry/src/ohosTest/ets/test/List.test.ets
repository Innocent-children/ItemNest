import appEventBusFlowTest from './AppEventBusFlow.test';
import abilityTest from './Ability.test';
import dataFailureMappingTest from './DataFailureMapping.test';
import refreshContractTest from './RefreshContract.test';

export default function testsuite() {
  abilityTest();
  appEventBusFlowTest();
  dataFailureMappingTest();
  refreshContractTest();
}

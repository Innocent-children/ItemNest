import appEventBusFlowTest from './AppEventBusFlow.test';
import abilityTest from './Ability.test';
import dataFailureMappingTest from './DataFailureMapping.test';
import homeSummaryFlowTest from './HomeSummaryFlow.test';
import refreshContractTest from './RefreshContract.test';

export default function testsuite() {
  abilityTest();
  appEventBusFlowTest();
  dataFailureMappingTest();
  homeSummaryFlowTest();
  refreshContractTest();
}

import inventoryUpgradeDeviceTest from './InventoryUpgradeDevice.test';
import appEventBusFlowTest from './AppEventBusFlow.test';
import abilityTest from './Ability.test';
import dataFailureMappingTest from './DataFailureMapping.test';
import homeSummaryFlowTest from './HomeSummaryFlow.test';
import homeSectionVisibilityTest from './HomeSectionVisibility.test';
import latestRequestCoordinatorTest from './LatestRequestCoordinator.test';
import refreshContractTest from './RefreshContract.test';
import searchRequestCoordinatorTest from './SearchRequestCoordinator.test';
import barcodeMigrationTest from './BarcodeMigration.test';
import portableBackupDeviceTest from './PortableBackupDevice.test';

export default function testsuite() {
  inventoryUpgradeDeviceTest();
  abilityTest();
  appEventBusFlowTest();
  dataFailureMappingTest();
  homeSummaryFlowTest();
  homeSectionVisibilityTest();
  latestRequestCoordinatorTest();
  refreshContractTest();
  searchRequestCoordinatorTest();
  barcodeMigrationTest();
  portableBackupDeviceTest();
}

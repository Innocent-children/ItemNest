import { describe, it, expect } from '@ohos/hypium';
import { SearchRequestCoordinator } from '../../../main/ets/common/SearchRequestCoordinator';

export default function searchRequestCoordinatorTest() {
  describe('SearchRequestCoordinator flow', () => {
    it('清空查询会作废搜索、刷新和建议请求', 0, () => {
      const coordinator = new SearchRequestCoordinator();
      const searchRequestId = coordinator.beginSearch();
      const suggestionRequestId = coordinator.beginSuggestion();
      const filterRequestId = coordinator.beginFilterOptions();

      coordinator.invalidateQueryRequests();

      expect(coordinator.isCurrentSearch(searchRequestId)).assertFalse();
      expect(coordinator.isCurrentSuggestion(suggestionRequestId)).assertFalse();
      expect(coordinator.isCurrentFilterOptions(filterRequestId)).assertTrue();

      const refreshCoordinator = new SearchRequestCoordinator();
      const refreshRequestId = refreshCoordinator.beginRefresh();
      refreshCoordinator.invalidateQueryRequests();

      expect(refreshCoordinator.isCurrentRefresh(refreshRequestId)).assertFalse();
    });

    it('搜索、刷新、建议和筛选使用隔离的请求序列', 0, () => {
      const coordinator = new SearchRequestCoordinator();
      const searchRequestId = coordinator.beginSearch();
      const suggestionRequestId = coordinator.beginSuggestion();
      const filterRequestId = coordinator.beginFilterOptions();
      const refreshRequestId = coordinator.beginRefresh();

      expect(coordinator.isCurrentSearch(searchRequestId)).assertFalse();
      expect(coordinator.isCurrentRefresh(refreshRequestId)).assertTrue();
      expect(coordinator.isCurrentSuggestion(suggestionRequestId)).assertTrue();
      expect(coordinator.isCurrentFilterOptions(filterRequestId)).assertTrue();
    });
  });
}

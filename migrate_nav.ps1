
$files = @(
  "entry\src\main\ets\pages\Index.ets",
  "entry\src\main\ets\components\EmptyState.ets",
  "entry\src\main\ets\components\ItemCard.ets",
  "entry\src\main\ets\pages\ItemDetailPage.ets",
  "entry\src\main\ets\pages\ItemListPage.ets",
  "entry\src\main\ets\pages\SearchPage.ets"
)

foreach ($f in $files) {
  $c = Get-Content -Raw -Encoding UTF8 $f

  # add import
  $importLine = "import { NavigationHelper } from '../navigation/NavigationHelper';"
  if ($c -notmatch [regex]::Escape($importLine)) {
    $c = $importLine + "
" + $c
  }

  # replace router.pushUrl({ url: X, params: Y })
  $c = [regex]::Replace($c, 'router\.pushUrl\(\{ url: ([^,]+), params: ([^}]+) \}\)', 'NavigationHelper.push($1, $2)')

  # replace router.pushUrl({ url: X })
  $c = [regex]::Replace($c, 'router\.pushUrl\(\{ url: ([^}]+) \}\)', 'NavigationHelper.push($1)')

  $c | Set-Content -Encoding UTF8 $f
  Write-Output "$f done"
}
Write-Output "all done"


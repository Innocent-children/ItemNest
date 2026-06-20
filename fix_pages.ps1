$pages = @(
  "entry\src\main\ets\pages\ItemDetailPage.ets",
  "entry\src\main\ets\pages\ItemFormPage.ets",
  "entry\src\main\ets\pages\SearchPage.ets"
);
foreach ($p in $pages) {
  $c = Get-Content -Raw -Encoding UTF8 $p;
  # Pattern: const params = router.getParams() as ...;
  # Insert if (!params) check after declarations
  $c = $c -replace 'const params = router\.getParams\(\) as Record<string, Object>;', 'const params = router.getParams() as Record<string, Object> | undefined;'
  if ($c -match 'if \(!params\)') { Write-Output "$p already fixed"; continue }
  $c = $c -replace '(const params = router\.getParams\(\) as Record<string, Object> \| undefined;)(\r?\n)(    const )', ('$1$2    if (!params) { this.errorMessage = ''\u9875\u9762\u53c2\u6570\u9519\u8bef''; this.loading = false; return; }$2$3')
  $c | Set-Content -Encoding UTF8 $p;
  Write-Output "$p patched"
}

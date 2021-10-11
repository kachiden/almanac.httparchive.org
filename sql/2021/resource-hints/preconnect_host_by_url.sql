#standardSQL
# Most popular hosts users preconnect to
# capped to one hit per url to avoid having the results skewed by websites which preconnect to the same host many times (!)


CREATE TEMPORARY FUNCTION getResourceHintsHrefs(payload STRING, hint STRING)
RETURNS ARRAY<STRING>
LANGUAGE js AS '''
try {
  var $ = JSON.parse(payload);
  var almanac = JSON.parse($._almanac);
  return almanac['link-nodes'].nodes.filter(link => link.rel.toLowerCase() == hint).map(n => n.href);
} catch (e) {  
  return [];
}
''' ;

SELECT
  client,
  host,
  COUNT(0) AS freq,
  SUM(COUNT(0)) OVER (PARTITION BY client) AS total,
  COUNT(0) / SUM(COUNT(0)) OVER (PARTITION BY client) AS pct
FROM (
  SELECT
    client,
    url,
    host
  FROM (
    SELECT
      _TABLE_SUFFIX AS client,
      url,
      NET.HOST(href) AS host
    FROM
      `httparchive.pages.2021_07_01_*`,
      UNNEST(getResourceHintsHrefs(payload, "preconnect")) AS href
  )
  GROUP BY
    client,
    url,
    host
)
GROUP BY
  client,
  host
HAVING
  freq > 1
ORDER BY
  client,
  freq DESC
LIMIT 100
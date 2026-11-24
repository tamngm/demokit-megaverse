-- Data quality summary of the uc5 raw tables: one row per check, with its issue count and PASS / FAIL.
-- Checks without issues are listed too (issue_count = 0, PASS). Details per record: uc5_srm_dq_issues_wk.

-- final: check catalogue + number of issues and projects affected
SELECT
    c.check_id,
    c.check_name,
    c.dimension,
    c.severity,
    c.table_name,
    c.description,
    count(i.check_id)                                        AS issue_count,
    count(DISTINCT i.oid)                                    AS oid_count,
    CASE WHEN count(i.check_id) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM {{ ref('uc5_srm_dq_checks_wk') }} c
LEFT JOIN {{ ref('uc5_srm_dq_issues_wk') }} i ON i.check_id = c.check_id
GROUP BY c.check_id, c.check_name, c.dimension, c.severity, c.table_name, c.description

-- Data quality checks run on the uc5 raw tables: one row per check (catalogue used by the issues and summary models).
-- To add a check: add a row here and its query in uc5_srm_dq_issues_wk.

-- final: check catalogue
SELECT *
FROM (
    VALUES
    ('C01', 'Quote without quote number',           'completeness', 'high',   'quotes',          'quote_number is NULL or empty: the quote and its lines are left out of the marts'),
    ('C02', 'Quote without supplier',               'completeness', 'high',   'quotes',          'supplier is NULL or empty: the quote cannot be linked to a supplier'),
    ('C03', 'Quote without editor',                 'completeness', 'medium', 'quotes',          'editor is NULL or empty: the quote cannot be linked to an editor'),
    ('C04', 'Quote line without quote number',      'completeness', 'high',   'quote_lines',     'quote_number is NULL or empty: the line is left out of the marts'),
    ('C05', 'Quote line without SKU',               'completeness', 'medium', 'quote_lines',     'sku is NULL or empty: the line cannot be linked to a product'),
    ('C06', 'Quote line without editor',            'completeness', 'medium', 'quote_lines',     'editor is NULL or empty on a quote line'),
    ('C07', 'Supplier without editor',              'completeness', 'medium', 'supplier_editor', 'a supplier row of the supplier list has no editor'),
    ('C08', 'Quote repeated',                       'uniqueness',   'medium', 'quotes',          'the same oid + quote_number appears on several rows (after removing exact duplicates)'),
    ('C09', 'Quote line without its quote',         'integrity',    'high',   'quote_lines',     'oid + quote_number of the line not found in quotes'),
    ('C10', 'SKU missing from the SKU list',        'integrity',    'low',    'quote_lines',     'a SKU used in quote lines is not in the SKU list (added to dim_sku from the lines)'),
    ('C11', 'Supplier missing from the supplier list', 'integrity', 'medium', 'quotes',          'a supplier of a quote is not in the supplier x editor list'),
    ('C12', 'Declared line count differs',          'consistency',  'low',    'quotes',          'lines declared on the quote <> lines found in quote_lines'),
    ('C13', 'Quote total differs from its lines',   'consistency',  'medium', 'quotes',          'total_net_excl_tax <> sum of line_total_net (gap above 1 and above 0.5%)'),
    ('C14', 'Dates in the wrong order',             'validity',     'medium', 'quotes',          'valid_until before quote_date, or contract_end before contract_start'),
    ('C15', 'Currency without exchange rate',       'validity',     'high',   'quotes, quote_lines', 'currency not in ref_exchange_rates: EUR amounts are NULL'),
    ('C16', 'Quote without quote date',             'completeness', 'high',   'quotes',          'quote_date is NULL: the quote has no place in the timeline (trends, history, first / last seen)')
) AS t (check_id, check_name, dimension, severity, table_name, description)

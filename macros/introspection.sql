
{% macro get_data(query, columns) %}

  {%- call statement('_', fetch_result=True) %}
    {{ query }}
  {% endcall %}

  {%- set records = load_result('_') -%}

  {% if not records %}
    {{ return([]) }}
  {% endif %}

  {%- set ret = [] -%}
  {% for record in records['data'] %}
    {% set processing = {} %}
    {% for column in columns %}
        {% set _ = processing.update({column: record[loop.index0]}) %}
    {% endfor %}
    {% set _ = ret.append(processing) %}
  {% endfor %}

  {{ return(ret) }}

{% endmacro %}


{% macro fetch_table_data(schema_name, table_name) %}

  {% set sql %}
    select
        schemaname,
        tablename,
        description,
        relation_type
    from dbt_dbanin.redshift_tables
    where schemaname = '{{ schema_name }}'
      and tablename = '{{ table_name }}'
  {% endset %}

  {% set table = get_data(sql, ['schema', 'name', 'description', 'type']) %}
  {{ return(table) }}

{% endmacro %}

{% macro fetch_column_data(schema_name, table_name) %}

  {% set sql %}
    select
        col_index,
        col_name,
        description,
        col_datatype,
        col_encoding,
        col_default,
        col_not_null
    from dbt_dbanin.redshift_columns
    where schemaname = '{{ schema_name }}'
      and tablename = '{{ table_name }}'
  {% endset %}

  {% set columns = get_data(sql, ['position', 'name', 'description', 'type', 'encoding', 'default', 'not_null']) %}

  {% set ret = {} %}
  {% for column in columns %}
      {%- set _ = ret.update({column.name: column}) -%}
  {% endfor %}

  {{ return(ret) }}

{% endmacro %}

{% macro fetch_sort_dist_key_data(schema_name, table_name) %}

  {% set sql %}
    select
        sort_style,
        sort_keys,
        diststyle,
        dist_key
    from dbt_dbanin.redshift_sort_dist_keys
    where schemaname = '{{ schema_name }}'
      and tablename = '{{ table_name }}'
  {% endset %}

  {% set keys = get_data(sql, ['sort_style', 'sort_keys', 'dist_style', 'dist_key']) %}
  {% for key in keys %}
    {% set _ = key.update({'sort_keys': key['sort_keys'].split('|')}) %}
  {% endfor %}

  {{ return(keys) }}

{% endmacro %}

{% macro fetch_constraints(schema_name, table_name) %}

  {% set sql %}
    select
        constraint_type,
        col_constraint
    from dbt_dbanin.redshift_constraints
    where schemaname = '{{ schema_name }}'
      and tablename = '{{ table_name }}'
  {% endset %}

  {% set constraints = get_data(sql, ['constraint_type', 'col_constraint']) %}
  {{ return(constraints) }}

{% endmacro %}


{% macro fetch_table_definition(schema_name, table_name) %}


  {% set tables = fetch_table_data(schema_name, table_name) %}

  {% if (tables | length) == 0 %}
    {{ return(none) }}
  {% elif (tables | length) > 1 %}
    {{ log(tables) }}
    {{ exceptions.raise_compiler_error("Expected one table") }}
  {% endif %}

  {% set table = tables[0] %}
  {% set columns = fetch_column_data(schema_name, table_name) %}
  {% set keys = fetch_sort_dist_key_data(schema_name, table_name) | first %}
  {% set constraints = fetch_constraints(schema_name, table_name) %}

  {% set _ = table.update({"columns": columns}) %}
  {% set _ = table.update({"keys": keys}) %}
  {% set _ = table.update({"constraints": constraints}) %}

  {{ return(table) }}

{% endmacro %}

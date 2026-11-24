# SAS-to-SQL command line interface

The CLI calls `sas2sql.transpile` from a separate directory. The bundle includes the attached sas2sql 0.3.0 compiler. It requires Lua 5.3 or 5.4 and LPeg 1.0 or later for the same Lua interpreter. Writing to a file also uses LuaFileSystem. With LuaRocks configured for that interpreter, install these libraries with `luarocks install lpeg` and `luarocks install luafilesystem`. [LuaFileSystem documentation](https://lunarmodules.github.io/luafilesystem/)

## Run a conversion

From the directory containing `sas2sql/` and `sas2sql-cli/`, run the included example.

```sh
lua sas2sql-cli/sas2sql \
  --input sas2sql-cli/examples/orders.sas \
  --schema sas2sql-cli/examples/schema.csv \
  --target spark \
  --output orders.sql
```

Use `--target` with `spark`, `pyspark`, `postgres`, `postgresql`, `sqlserver`, `oracle`, or `snowflake`. Both Spark targets emit Spark SQL. For Iceberg CTAS, pass `--spark-table-provider iceberg` with either Spark target. The default preserves SAS missing values where the target supports it. `--collapse-special-missing` opts in to collapsing special numeric missings to SQL NULL.

The CLI writes generated statements in compiler order to a SQL file in an existing directory. Output table names come from the SAS program. On POSIX systems, a successful run replaces an existing output file at that path. Choose a separate path from your inputs. Use `--output -` to write SQL to stdout. Compiler warnings and errors go to stderr with source locations when available. Exit status `0` indicates success, `1` indicates a file, schema, or compiler error, and `2` indicates invalid options. A compilation error leaves the previous output file intact.

Run `lua sas2sql-cli/sas2sql --help` to list options. The CLI looks for a sibling `sas2sql/` source tree and otherwise uses the normal Lua module search path. Pass `--compiler-root /path/to/sas2sql` to choose a specific unpacked compiler. On POSIX systems you can also run `./sas2sql-cli/sas2sql` directly.

## Define the input schema

Provide a UTF-8, comma-delimited file with one row per column in each external input dataset. Use the physical column spelling from the target table. Dataset lookup is case-insensitive. Unqualified SAS datasets use `WORK` for schema lookup. The compiler derives schemas for tables it creates earlier in the same program. For a program with no external inputs, use a CSV containing just the header.

| Header | Value |
| --- | --- |
| `libname` | SAS libref, such as `WORK` or `SALES` |
| `memname` | SAS dataset member, such as `ORDERS` |
| `name` | Physical column name. Use CSV quoting for names containing commas or double quotes. |
| `type` | One of `character`, `numeric`, `date`, `datetime`, or `time`. Native `PROC CONTENTS` codes `1` and `2` mean `numeric` and `character`. |
| `length` | SAS storage length in bytes. Required for `character`. For other types this can be blank. |
| `varnum` | Positive column position within the dataset. The CLI sorts columns by this value. |
| `format` | Optional SAS format name, such as `DATE9.` |
| `informat` | Optional SAS informat name, such as `ANYDTDTE.` |

The first six headers are required. Header names and type values are case-insensitive. The CLI accepts extra `PROC CONTENTS` columns and checks for duplicate names or positions within a dataset.

| CSV type | Expected value in the target table |
| --- | --- |
| `character` | SAS character values, including codes and character IDs |
| `numeric` | SAS numbers, including amounts, numeric IDs, and 0/1 flags |
| `date` | Numeric days since 1960-01-01 |
| `datetime` | Numeric seconds since 1960-01-01 00:00:00, with fractional seconds allowed |
| `time` | Numeric seconds since midnight, with fractional seconds allowed |

The temporal types describe numeric SAS storage. The CLI passes them to the compiler as `numeric`, and the SQL expects the original SAS units. Formatting metadata describes how SAS reads or displays a value. Currency, percentages, and custom-formatted numbers use `numeric`. The CSV covers column metadata. Ordered DATA-step operations that require verified observation sequences, sort order, or key uniqueness use the compiler's Lua `observation_order` option.

## Export the schema from SAS

Open `export_schema.sas` in SAS, set the `DATA=` input to your dataset or a source library such as `sales._all_`, and set the output filename. The script uses `PROC CONTENTS` and `PROC EXPORT`. It uses `FMTINFO` in SAS 9.4M3 or later to recognize temporal formats and informats. Review `type` for unformatted values or custom formats with no temporal category, and set it explicitly where needed. For earlier SAS versions, you can export the `PROC CONTENTS` output directly and edit `TYPE` in the CSV if you want explicit temporal labels. [SAS CONTENTS output columns](https://support.sas.com/documentation/cdl/en/proc/65145/HTML/default/p1sy9ca8n2tv03n1savk4p9cmeq0.htm), [SAS FMTINFO reference](https://support.sas.com/resources/papers/proceedings17/SAS0209-2017.pdf), [SAS PROC EXPORT reference](https://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/a000316288.htm)

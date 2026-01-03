# Connection Set Dynamic Routing - Implementation Summary

## What Was Implemented

### 1. Connection Set-Aware Execution Context
- **New Function**: `mkPGExecCtxWithConnectionSet` in `Execute/Types.hs`
- **Purpose**: Creates an execution context that can route queries to different connection pools based on resolved connection templates
- **Key Features**:
  - Manages multiple connection pools (primary, read replicas, connection set members)
  - Handles pool destruction and resizing for all pools
  - Routes transactions to the correct pool based on `PostgresResolvedConnectionTemplate`

### 2. Pool Selection Logic
- **New Function**: `selectPoolForExecution` in `Execute/Types.hs`
- **Purpose**: Selects the appropriate connection pool based on the resolved connection template
- **Routing Logic**:
  - `PCTOPrimary` → Primary pool
  - `PCTODefault` → Read replica for read operations, primary for writes
  - `PCTOReadReplicas` → Read replica pool (fallback to primary)
  - `PCTOConnectionSet memberName` → Specific connection set member pool (fallback to primary)

### 3. Enhanced Source Resolver
- **Modified Function**: `mkPgSourceResolver` in `App.hs`
- **New Features**:
  - Parses connection set configuration from `pccConnectionSet`
  - Creates connection pools for each connection set member
  - Enables connection template configuration when present
  - Uses connection set-aware execution context when connection sets are configured

### 4. Connection Set Member Pool Creation
- **New Function**: `createConnectionSetMemberPool` in `App.hs`
- **Purpose**: Creates individual connection pools for each connection set member
- **Features**:
  - Respects individual pool settings per connection set member
  - Proper error handling and resource management

## How It Works

### Configuration Example
```yaml
sources:
  - name: my_postgres_source
    configuration:
      connection_info:
        database_url: "postgresql://primary_db"
      connection_set:
        - name: "tenant_a"
          connection_info:
            database_url: "postgresql://tenant_a_db"
        - name: "tenant_b" 
          connection_info:
            database_url: "postgresql://tenant_b_db"
      connection_template: |
        {% if request.headers.tenant == "tenant_a" %}
          {{ connection_set.tenant_a }}
        {% elif request.headers.tenant == "tenant_b" %}
          {{ connection_set.tenant_b }}
        {% else %}
          {{ primary }}
        {% endif %}
```

### Query Flow
1. **GraphQL Query Received** → Headers include `tenant: tenant_a`
2. **Connection Template Evaluation** → Kriti template evaluates to `PCTOConnectionSet "tenant_a"`
3. **Pool Selection** → `selectPoolForExecution` routes to `tenant_a` connection pool
4. **Query Execution** → Query runs against tenant A's database

### Fallback Behavior
- If connection set member not found → Falls back to primary pool
- If read replica not available → Falls back to primary pool
- If connection template evaluation fails → Uses default routing logic

## Testing Your Implementation

### 1. Verify Configuration Parsing
Check that your connection set configuration is being parsed correctly:
```bash
# Check Hasura logs for connection pool creation messages
# Should see logs for each connection set member pool
```

### 2. Test Template Evaluation
Use the connection template test endpoint:
```graphql
mutation {
  test_connection_template(
    args: {
      source_name: "my_postgres_source"
      request_context: {
        headers: { tenant: "tenant_a" }
        session: {}
      }
    }
  ) {
    routing_to
    value
  }
}
```

### 3. Verify Query Routing
Add different data to each database and verify queries hit the right one:
```graphql
# With header: tenant: tenant_a
query {
  users {
    id
    name
  }
}
# Should return data from tenant A database
```

## Troubleshooting

### Common Issues
1. **Template evaluates correctly but still uses primary**
   - Check that connection set pools were created successfully
   - Verify connection set member names match template output

2. **Connection pool errors**
   - Check database URLs in connection set configuration
   - Verify database permissions and connectivity

3. **Template evaluation fails**
   - Check Kriti template syntax
   - Verify request context structure matches template expectations

### Debug Logging
Enable debug logging to see:
- Connection pool creation
- Template evaluation results
- Pool selection decisions

## Next Steps

1. **Test with your specific configuration**
2. **Add monitoring/metrics for connection set usage**
3. **Consider adding connection set health checks**
4. **Add support for read replica routing within connection sets**

The implementation is now complete and should support dynamic routing based on connection templates in the Community Edition!
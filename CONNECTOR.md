# Connector Documentation

## Overview

Connectors in our system are modular components that enable interaction with various external protocols or services. They provide a standardized way to extend the functionality of the main contract without modifying its core code. Our system uses a simple versioning system for better management and compatibility checks.

## Connector Structure

Each connector version is defined by the following properties:

- **Address**: The unique Ethereum address of the connector contract.
- **Name**: A human-readable identifier for the connector.
- **Version**: A simple incremental version number (v1, v2, v3, etc.).
- **Active Status**: A boolean indicating whether this specific version of the connector is currently active and usable.

## Versioning

We use a simple, incremental versioning system for all connectors. Versions are represented as positive integers (1, 2, 3, etc.).

- Each new version of a connector must have a higher version number than the previous one.
- Multiple versions of a connector can coexist in the registry, allowing for gradual upgrades and backwards compatibility.

## Connector Lifecycle

### Adding a Connector Version

New connector versions can be added to the registry by the contract owner. When adding a connector version, you must provide:

- The connector's contract address
- A name for the connector
- The version number (must be greater than the current latest version)

### Updating a Connector Version

Existing connector versions can be updated by the contract owner. Updates can modify:

- The connector version's name
- The active status of the version

### Deactivating a Connector Version

Specific versions of connectors can be deactivated by the contract owner. Deactivated versions remain in the registry but are marked as inactive and should not be used for operations.

## Using Connectors

Approved (active) connector versions can be used to interact with external protocols or services. The main contract will typically provide methods to execute actions through these connectors.

Always check a connector's active status and version before use to ensure compatibility with your application.

## Version Management

The system provides several functions to manage and query connector versions:

- `getLatestConnectorVersion`: Retrieves the latest version number of a specific connector.
- `isApprovedConnector`: Checks if a specific version of a connector is active and approved for use.

## Best Practices

1. **Version Incrementally**: Always increment the version number for any changes to a connector.
2. **Document Changes**: Maintain a changelog for each connector, detailing changes in each version.
3. **Test Thoroughly**: Ensure comprehensive testing of new and updated connector versions before adding them to the registry.


## Security Considerations

- Only the contract owner can add, update, or deactivate connector versions.
- Always verify the source and integrity of a connector before adding it to the registry. Should have a governance team do this
- Consider implementing a time-lock or multi-sig mechanism for sensitive operations like adding or updating connectors.

## Future Developments

We are continuously working on improving the connector system. Future updates may include:

- More granular permissions for connector management
- Automatic compatibility checks when executing connector functions
- A connector marketplace for easy discovery and integration of new connectors

Stay tuned for updates and feel free to contribute ideas for improving the connector ecosystem!
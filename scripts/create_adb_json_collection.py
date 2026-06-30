#!/usr/bin/env python3
import argparse
import datetime
import subprocess
import sys

MongoClient = None
CollectionInvalid = Exception
OperationFailure = Exception
ServerSelectionTimeoutError = Exception


def load_pymongo():
    global MongoClient, CollectionInvalid, OperationFailure, ServerSelectionTimeoutError

    try:
        from pymongo import MongoClient as pymongo_client
        from pymongo.errors import CollectionInvalid as pymongo_collection_invalid
        from pymongo.errors import OperationFailure as pymongo_operation_failure
        from pymongo.errors import ServerSelectionTimeoutError as pymongo_server_selection_timeout
    except ImportError:
        print("Missing dependency: pymongo", file=sys.stderr)
        print("Install it with: python3 -m pip install pymongo", file=sys.stderr)
        sys.exit(2)

    MongoClient = pymongo_client
    CollectionInvalid = pymongo_collection_invalid
    OperationFailure = pymongo_operation_failure
    ServerSelectionTimeoutError = pymongo_server_selection_timeout


def terraform_output(terraform_dir, name):
    result = subprocess.run(
        ["terraform", "-chdir=" + terraform_dir, "output", "-raw", name],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def build_client(connection_string, timeout_ms):
    kwargs = {"serverSelectionTimeoutMS": timeout_ms}

    try:
        import certifi

        kwargs["tlsCAFile"] = certifi.where()
    except ImportError:
        pass

    return MongoClient(connection_string, **kwargs)


def main():
    parser = argparse.ArgumentParser(
        description="Create the OCI Autonomous JSON Database Mongo-compatible collection used by the lab app."
    )
    parser.add_argument(
        "--terraform-dir",
        default=".",
        help="Terraform directory used to read outputs when connection details are not passed explicitly.",
    )
    parser.add_argument(
        "--connection-string",
        help="ADB MongoDB API connection string. Defaults to terraform output adb_mongodb_connection_string.",
    )
    parser.add_argument(
        "--database",
        default="admin",
        help="Mongo database name used by the Flask app. Default: admin.",
    )
    parser.add_argument(
        "--collection",
        help="Collection name. Defaults to terraform output app_collection_name.",
    )
    parser.add_argument(
        "--recreate",
        action="store_true",
        help="Drop and recreate the collection. This deletes existing collection data.",
    )
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=30000,
        help="Mongo server selection timeout in milliseconds.",
    )
    args = parser.parse_args()

    load_pymongo()

    connection_string = args.connection_string or terraform_output(
        args.terraform_dir, "adb_mongodb_connection_string"
    )
    collection_name = args.collection or terraform_output(args.terraform_dir, "app_collection_name")

    client = build_client(connection_string, args.timeout_ms)
    db = client[args.database]
    marker_id = "__oci_foundations_lab_collection_marker__"

    try:
        client.admin.command("ping")

        if args.recreate:
            db.drop_collection(collection_name)
            print(f"Dropped collection {args.database}.{collection_name}")

        try:
            db.create_collection(collection_name)
            print(f"Created collection {args.database}.{collection_name}")
        except CollectionInvalid:
            print(f"Collection {args.database}.{collection_name} already exists")
        except OperationFailure as exc:
            # Some Mongo-compatible services prefer implicit creation by insert.
            print(f"create_collection returned {exc}; falling back to insert/delete marker")

        db[collection_name].replace_one(
            {"_id": marker_id},
            {
                "_id": marker_id,
                "created_by": "create_adb_json_collection.py",
                "created_at": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
            },
            upsert=True,
        )
        db[collection_name].delete_one({"_id": marker_id})

        names = db.list_collection_names()
        if collection_name not in names:
            raise RuntimeError(f"Collection {collection_name} was not found after creation attempt")

        print(f"Verified collection {args.database}.{collection_name}")
    except (OperationFailure, ServerSelectionTimeoutError, RuntimeError) as exc:
        print(f"Failed to create collection: {exc}", file=sys.stderr)
        sys.exit(1)
    finally:
        client.close()


if __name__ == "__main__":
    main()

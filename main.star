load("@kurtosis:core.star", "ServiceConfig", "FileArtifactID")

def run(plan, args):
    plan.print("🚀 Starting Lighthouse + Postgres testnet...")

    # Read args
    postgres_image = args.get("postgres_image", "postgres:16")
    lighthouse_image = args.get("lighthouse_image", "sigp/lighthouse:unstable")
    postgres_user = args.get("postgres_user", "postgres")
    postgres_password = args.get("postgres_password", "admin")
    postgres_db = args.get("postgres_db", "store")

    # _______________________________________________________________________________
    # 1. Start Postgres
    # _______________________________________________________________________________
    plan.print("Starting Postgres service...")
    postgres_service = plan.add_service(
        name = "postgres",
        config = ServiceConfig(
            image = postgres_image,
            ports = {
                "postgres": 5432,
            },
            env_vars = {
                "POSTGRES_USER": postgres_user,
                "POSTGRES_PASSWORD": postgres_password,
                "POSTGRES_DB": postgres_db,
            },
            cmd = [
                "postgres",
                "-c", "fsync=off",
                "-c", "full_page_writes=off",
            ],
        ),
    )

    postgres_host = postgres_service.hostname()
    plan.print("✅ Postgres running at host: {}".format(postgres_host))

    # _______________________________________________________________________________
    # 2. Start Execution Layer (Geth)
    # _______________________________________________________________________________
    plan.print("Starting Geth (execution client)...")
    el_service = plan.add_service(
        name = "geth",
        config = ServiceConfig(
            image = "ethereum/client-go:latest",
            ports = {
                "rpc": 8545,
                "ws": 8546,
                "engine": 8551,
                "metrics": 9001,
            },
            cmd = [
                "--http",
                "--http.addr", "0.0.0.0",
                "--http.vhosts", "*",
                "--http.api", "engine,eth,net,web3",
                "--authrpc.addr", "0.0.0.0",
                "--authrpc.port", "8551",
                "--authrpc.vhosts", "*",
                "--syncmode", "full",
            ],
        ),
    )

    el_rpc = "http://{}:{}".format(el_service.hostname(), 8545)
    engine_api = "{}:{}".format(el_service.hostname(), 8551)
    plan.print("✅ Geth running at {}".format(el_rpc))

    # _______________________________________________________________________________
    # 3. Start Lighthouse Beacon Node (with Postgres backend)
    # _______________________________________________________________________________
    plan.print("Starting Lighthouse beacon node with Postgres backend...")

    lighthouse_service = plan.add_service(
        name = "lighthouse-bn",
        config = ServiceConfig(
            image = lighthouse_image,
            ports = {
                "http": 5052,
                "metrics": 5054,
            },
            cmd = [
                "lighthouse", "bn",
                "--network", "mainnet",
                "--execution-endpoint", "http://{}".format(engine_api),
                "--execution-jwt", "/jwtsecret/jwt.hex",
                "--http",
                "--http-address", "0.0.0.0",
                "--http-port", "5052",
                "--metrics",
                "--metrics-address", "0.0.0.0",
                "--metrics-port", "5054",
                "--beacon-node-backend", "postgres",
                "--postgres-url", "postgresql://{}:{}@{}:5432/{}".format(
                    postgres_user, postgres_password, postgres_host, postgres_db
                ),
                "--datadir", "/data/lighthouse",
            ],
            files = {
                "/jwtsecret/jwt.hex": FileArtifactID(args.get("jwt_file_artifact", "")),
            },
        ),
    )

    plan.print("✅ Lighthouse beacon node with Postgres backend started successfully")

    plan.print(
        """
🎯 Testnet launched successfully!
- Geth RPC:        http://localhost:8545
- Lighthouse REST: http://localhost:5052
- Postgres:        postgresql://postgres:admin@localhost:5432/store
"""
    )

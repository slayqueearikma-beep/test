import sql from "mssql";

let pool;

export async function getPool() {
  if (pool) {
    return pool;
  }

  const connectionString = process.env.SCAD_FINOPS_SQL_CONNECTION_STRING;
  if (!connectionString) {
    throw new Error("SCAD_FINOPS_SQL_CONNECTION_STRING is not configured.");
  }

  pool = await sql.connect(connectionString);
  return pool;
}

export async function ensureSchema() {
  const db = await getPool();
  await db.request().query(`
    IF OBJECT_ID('cost_files', 'U') IS NULL
    BEGIN
      CREATE TABLE cost_files (
        id INT IDENTITY(1,1) PRIMARY KEY,
        blob_path NVARCHAR(1024) NOT NULL,
        export_type NVARCHAR(64) NULL,
        row_estimate INT NULL,
        ingested_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
      );
    END;

    IF OBJECT_ID('pipeline_runs', 'U') IS NULL
    BEGIN
      CREATE TABLE pipeline_runs (
        id INT IDENTITY(1,1) PRIMARY KEY,
        workflow NVARCHAR(128) NOT NULL,
        run_id NVARCHAR(64) NOT NULL,
        status NVARCHAR(32) NOT NULL,
        conclusion NVARCHAR(32) NULL,
        duration_seconds INT NULL,
        risk_score DECIMAL(6,2) NULL,
        risk_decision NVARCHAR(32) NULL,
        commit_sha NVARCHAR(64) NULL,
        environment NVARCHAR(64) NULL,
        recorded_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
      );
    END;
  `);
}

export async function insertCostFile({ blobPath, exportType, rowEstimate }) {
  const db = await getPool();
  await db.request()
    .input("blobPath", sql.NVarChar(1024), blobPath)
    .input("exportType", sql.NVarChar(64), exportType)
    .input("rowEstimate", sql.Int, rowEstimate)
    .query(`
      INSERT INTO cost_files (blob_path, export_type, row_estimate)
      VALUES (@blobPath, @exportType, @rowEstimate)
    `);
}

export async function insertPipelineRun(record) {
  const db = await getPool();
  await db.request()
    .input("workflow", sql.NVarChar(128), record.workflow)
    .input("runId", sql.NVarChar(64), record.runId)
    .input("status", sql.NVarChar(32), record.status)
    .input("conclusion", sql.NVarChar(32), record.conclusion)
    .input("durationSeconds", sql.Int, record.durationSeconds)
    .input("riskScore", sql.Decimal(6, 2), record.riskScore)
    .input("riskDecision", sql.NVarChar(32), record.riskDecision)
    .input("commitSha", sql.NVarChar(64), record.commitSha)
    .input("environment", sql.NVarChar(64), record.environment)
    .query(`
      INSERT INTO pipeline_runs (
        workflow, run_id, status, conclusion, duration_seconds,
        risk_score, risk_decision, commit_sha, environment
      )
      VALUES (
        @workflow, @runId, @status, @conclusion, @durationSeconds,
        @riskScore, @riskDecision, @commitSha, @environment
      )
    `);
}

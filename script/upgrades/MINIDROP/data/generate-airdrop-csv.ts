// Each execution of this will consume the following amount of credits:
// Formula: Credits = Datapoints / Datapoints per credit
// since we are on the premium plan, we have 25.000 datapoints per credit
// The Datapoints are calculated by the number of rows * the number of columns
// In our case, as of writing this, we have 3.648.047 rows and 5 columns
// Meaning per execution we consume: (3.648.047 * 5) / 25.000 = 729,6 credits

import { config } from "dotenv";
import { createObjectCsvWriter } from "csv-writer";
import Decimal from "decimal.js";
import fs from "fs";
import path from "path";

interface Airdrop {
  address: string;
  mentoAllocation: string;
  cUSDAllocation: string;
}

config();

const MENTO_THRESHOLD = new Decimal(1e18);

async function run() {
  const duneApiKey = process.env.DUNE_API_KEY;
  if (!duneApiKey) {
    console.error("🚨 Missing DUNE_API_KEY environment variable");
    process.exit(1);
  }

  const mentoFilepath = path.resolve(__dirname, "mento_airdrop.csv");
  const cUSDFilepath = path.resolve(__dirname, "cusd_airdrop.csv");
  clearFileContents(mentoFilepath);
  clearFileContents(cUSDFilepath);

  const mentoCsvWriter = createObjectCsvWriter({
    path: mentoFilepath,
    header: [
      { id: "address", title: "Address" },
      { id: "mentoAllocation", title: "MENTO Allocation" },
    ],
    append: true,
  });

  const cUSDCsvWriter = createObjectCsvWriter({
    path: cUSDFilepath,
    header: [
      { id: "address", title: "Address" },
      { id: "cUSDAllocation", title: "cUSD Allocation" },
    ],
    append: true,
  });

  const queryId = 3932204; // https://dune.com/queries/3932204
  const options = { method: "GET", headers: { "X-DUNE-API-KEY": duneApiKey } };
  const limit = 1000;
  let uri = `https://api.dune.com/api/v1/query/${queryId}/results?limit=${limit}`;

  let hasMorePages = true;
  let rowsFetched = 0;
  let totalRowCount = 0;

  while (hasMorePages) {
    try {
      const response = await fetch(uri, options);
      const jsonResponse = await response.json();

      if (!totalRowCount) {
        totalRowCount = jsonResponse.result.metadata.total_row_count;
      }

      const data = processRows(jsonResponse.result.rows);
      rowsFetched += jsonResponse.result.rows.length;

      console.log(`⏳ ${rowsFetched}/${totalRowCount} records fetched`);

      if (data.length > 0) {
        const mentoData = data.map(({ address, mentoAllocation }) => ({ address, mentoAllocation }));
        const cUSDData = data.map(({ address, cUSDAllocation }) => ({ address, cUSDAllocation }));

        await mentoCsvWriter.writeRecords(mentoData);
        await cUSDCsvWriter.writeRecords(cUSDData);
        console.log(`${data.length} records written to both CSV files 📝`);
      }

      hasMorePages = jsonResponse.next_uri != undefined;
      uri = jsonResponse.next_uri || "";
    } catch (err) {
      console.error(`🚨 Error processing data: ${err}`);
      break;
    }
  }
}

// Calculate the allocations
// Formula:
// MENTO Allocation = amountTransferred * 0.1 + avgAmountHeld
// cUSD Allocation = MENTO Allocation * 0.1
// Filter out allocations with less than 1 Mento earned
function processRows(rows: any[]): Airdrop[] {
  return rows
    .map((row: any) => {
      const amountTransferred = new Decimal(row.amount_transferred).times(1e18).floor();
      const avgAmountHeld = new Decimal(row.avg_amount_held).times(1e18).floor();

      const tenPercentTransferred = amountTransferred.times(0.1).floor();
      const mentoAllocation = tenPercentTransferred.plus(avgAmountHeld);
      const cUSDAllocation = mentoAllocation.times(0.1).floor();

      return {
        address: row.address,
        mentoAllocation: mentoAllocation.toString(),
        cUSDAllocation: cUSDAllocation.toString(),
      };
    })
    .filter((item): item is Airdrop => new Decimal(item.mentoAllocation).greaterThanOrEqualTo(MENTO_THRESHOLD));
}

function clearFileContents(filePath: string): void {
  fs.writeFileSync(filePath, "", { flag: "w" });
  console.log(`Contents of ${path.basename(filePath)} have been cleared 🧹`);
}

run().catch(console.error);

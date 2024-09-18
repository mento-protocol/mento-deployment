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

async function run() {
  const duneApiKey = process.env.DUNE_API_KEY;
  const filepath = path.resolve(__dirname, "airdrop.csv");
  clearFileContents(filepath);

  const csvWriter = createObjectCsvWriter({
    path: filepath,
    header: [
      { id: "address", title: "Address" },
      { id: "mentoAllocation", title: "MENTO Allocation" },
      { id: "cUSDAllocation", title: "cUSD Allocation" },
    ],
    append: false,
  });

  const queryId = 3932204; // https://dune.com/queries/3932204

  if (!duneApiKey) {
    console.error("🚨 Missing DUNE_API_KEY environment variable");
    process.exit(1);
  }

  const options = { method: "GET", headers: { "X-DUNE-API-KEY": duneApiKey } };
  const limit = 10000;
  let uri = `https://api.dune.com/api/v1/query/${queryId}/results?limit=${limit}`;

  let hasMorePages = true;
  let rowsFetched = 0;
  while (hasMorePages) {
    let jsonResponse;
    try {
      const response = await fetch(uri, options);
      jsonResponse = await response.json();
      rowsFetched += jsonResponse.result.rows.length;
      console.log(`⏳ ${rowsFetched}/${jsonResponse.result.metadata.total_row_count} records fetched`);
    } catch (err) {
      console.error(err);
    }

    // Calculate the allocations
    // Formula:
    // MENTO Allocation = amountTransfered * 0.1 + avgAmountHeld
    // cUSD Allocation = MENTO Allocation * 0.1
    const data: Airdrop[] = jsonResponse.result.rows.map((row: any) => {
      const amountTransferred = new Decimal(row.amount_transferred).times(1e18).floor();
      const avgAmountHeld = new Decimal(row.avg_amount_held).times(1e18).floor();

      const tenPercentTransferred = new Decimal(amountTransferred).times(0.1).floor();

      const mentoAllocation = tenPercentTransferred.plus(avgAmountHeld);
      const cUSDAllocation = mentoAllocation.times(0.1).floor();
      return {
        address: row.address,
        mentoAllocation: mentoAllocation.toString(),
        cUSDAllocation: cUSDAllocation.toString(),
      };
    });

    csvWriter
      .writeRecords(data)
      .then(() => console.log(`${data.length} records written to CSV file 📝`))
      .catch(err => console.error("🚨 Error updating CSV file", err));

    hasMorePages = jsonResponse.next_uri != undefined;
    if (hasMorePages) {
      uri = jsonResponse.next_uri;
    }
  }
}

function clearFileContents(filePath: string): void {
  fs.writeFileSync(filePath, "", { flag: "w" });
  console.log("Contents of airdrop.csv have been cleared 🧹");
}

run().catch(console.error);

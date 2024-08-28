export const delay = (ms: number) => new Promise(res => setTimeout(res, ms));

export enum VerificationStatus {
  FAILED = "Fail - Unable to verify",
  SUCCESS = "Pass - Verified",
  PENDING = "Pending in queue",
  ALREADY_VERIFIED = "Contract source code already verified",
}

type VerifyParams = {
  api: string;
  apiKey: string | undefined;
  contract: string;
  source: any;
  target: string;
  version: string;
  args: string;
};

type CheckParams = {
  api: string;
  apiKey: string | undefined;
  contract: string;
}

export async function check({ api, apiKey, contract }: CheckParams): Promise<boolean> {
  const params = new URLSearchParams();
  if (apiKey) {
    params.append("apikey", apiKey);
  }
  params.append("module", "contract");
  params.append("action", "getabi");
  params.append("address", contract);

  const data = await fetch(api, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
    body: params,
  }).then(res => res.json());
  return data['message'] === "OK" && data['status'] === "1";
}

export async function verify({ api, apiKey, contract, source, target, version, args }: VerifyParams): Promise<string> {
  const params = new URLSearchParams();
  if (apiKey) {
    params.append("apikey", apiKey);
  }
  params.append("module", "contract");
  params.append("action", "verifysourcecode");
  params.append("contractaddress", contract);
  params.append("sourceCode", JSON.stringify(source));
  params.append("codeformat", "solidity-standard-json-input");
  params.append("contractname", target);
  params.append("compilerversion", version);
  params.append("constructorArguements", args);

  const data = await fetch(api, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
    body: params,
  }).then(res => res.json());

  return data.result;
}

export async function waitFor(api: string, apiKey: string | undefined, guid: string): Promise<string> {
  while (true) {
    await delay(3000);

    const params = new URLSearchParams();
    if (apiKey) {
      params.append("apiKey", apiKey);
    }
    params.append("module", "contract");
    params.append("action", "checkverifystatus");
    params.append("guid", guid);

    const data = await fetch(api + "?" + params).then(res => res.json());
    if (data.result !== VerificationStatus.PENDING) {
      return data.result;
    }
  }
}

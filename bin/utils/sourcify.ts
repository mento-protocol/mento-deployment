export const SOURCIFY_API = "https://sourcify.dev/server/";

export async function check(chainId: number, contract: string): Promise<string> {
  const data = await fetch(`${SOURCIFY_API}check-all-by-addresses?addresses=${contract}&chainIds=${chainId}`).then(
    res => res.json(),
  );
  if (!data || !data[0]) {
    return "false";
  }
  const chainStatus = data[0].chainIds.find(
    (match: { chainId: string, status: string }) => match.chainId === chainId.toString()
  )
  return chainStatus && chainStatus.status
}

export async function files(chainId: number, contract: string): Promise<any> {
  const data = await fetch(`${SOURCIFY_API}files/any/${chainId}/${contract}`).then(res => res.json());

  return data.files;
}

export type Metadata = {
  language: string;
  settings: any;
};
type SourcifyOutput = {
  metadata: Metadata;
  version: string;
  sources: any;
  target: string;
  constructorArgs: string;
  libraryMap: Record<string, string>;
};
type FileContent = {
  content: string;
};
type File = FileContent & {
  name: string;
  path: string;
};

export function parseFiles(files: any): SourcifyOutput {
  const metadata = JSON.parse(files.find((file: File) => file.name === "metadata.json").content);
  const constructorArgs = files.find((file: File) => file.name === "constructor-args.txt");
  const libraryMapFile = files.find((file: File) => file.name === "library-map.json");
  const libraryMap = libraryMapFile ? JSON.parse(libraryMapFile.content) : {};
  const sourcesArray = files.filter(
    (file: File) =>
      file.name !== "metadata.json" && file.name !== "constructor-args.txt" && !file.name.endsWith("json") && !file.name.endsWith("txt")
  );
  const version = `v${metadata.compiler.version}`;
  const target = Object.entries(metadata.settings.compilationTarget)[0].join(":");
  const sources: { [key: string]: FileContent } = {};

  const prefix = sourcesArray.find((file: File) => file.path.match(/^.*\/sources\//))!.path.match(/^.*\/sources\//)[0];
  for (const file of sourcesArray) {
    const path = file.path.replace("sources/_", "sources/@").slice(prefix.length);
    sources[path] = { content: file.content };
  }

  return {
    metadata,
    version,
    target,
    sources,
    constructorArgs: constructorArgs ? constructorArgs.content.slice(2) : "",
    libraryMap,
  };
}

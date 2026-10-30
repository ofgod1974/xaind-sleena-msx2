import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const result=spawnSync(process.execPath,[path.join(root,'build.cjs'),...process.argv.slice(2)],{cwd:root,stdio:'inherit'});
if(result.error)throw result.error;
process.exit(result.status||0);

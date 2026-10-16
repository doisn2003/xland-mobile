// Generates adapters from C-owned Dart domain declarations without changing signatures.
import {readFileSync,writeFileSync} from 'node:fs';
const entityRoot='lib/domain/entities/';
const files=['common','property','social','consultant','event','booking','account','finance'];
const common=readFileSync(entityRoot+'common.dart','utf8');
const enums=[...common.matchAll(/enum (\w+) \{([\s\S]*?)\}/g)].map(([,name,values])=>({name,values:values.split(',').map(s=>s.trim()).filter(s=>/^[a-z]\w*$/.test(s))}));
const snake=s=>s.replace(/[A-Z]/g,x=>'_'+x.toLowerCase());
const override={below100:'below_100',from100To200:'from_100_to_200',above200:'above_200'};
let output=`// Generated from the locked domain. Run node tool/generate_wire_mappers.mjs after reviewed model changes.\nimport '../../domain/xland_domain.dart';\nimport 'wire_values.dart';\n\nMap<String, Object?> wireObject(Object? value) {\n  if (value is! Map<String, Object?>) throw const FormatException('Expected object');\n  return value;\n}\nObject? wireField(Map<String,Object?> value,String key) {\n  if (!value.containsKey(key)) throw FormatException('Missing field: $key');\n  return value[key];\n}\nString wireString(Object? value) { if(value is! String) throw const FormatException('Expected string'); return value; }\nint wireInt(Object? value) { if(value is! int || value<0 || value>9007199254740991) throw const FormatException('Expected nonnegative safe integer'); return value; }\nbool wireBool(Object? value) { if(value is! bool) throw const FormatException('Expected boolean'); return value; }\ndouble wireDouble(Object? value) { if(value is! num || !value.isFinite) throw const FormatException('Expected finite number'); return value.toDouble(); }\nUri wireUri(Object? value) { final uri=Uri.parse(wireString(value)); if(uri.scheme!='https'||uri.host.isEmpty) throw const FormatException('Expected HTTPS URL'); return uri; }\nT? wireNullable<T>(Object? value,T Function(Object?) map) => value==null?null:map(value);\nList<T> wireList<T>(Object? value,T Function(Object?) map) { if(value is! List<Object?>) throw const FormatException('Expected list'); return List.unmodifiable(value.map(map)); }\n\n`;
for(const {name,values}of enums){
 output+=`${name} map${name}(Object? value) {\n  switch(value) {\n`+values.map(v=>`    case '${override[v]??snake(v)}': return ${name}.${v};`).join('\n')+`\n    default: throw const FormatException('Unknown ${name}');\n  }\n}\n`;
 output+=`String write${name}(${name} value) => switch(value) {\n`+values.map(v=>`  ${name}.${v} => '${override[v]??snake(v)}',`).join('\n')+'\n};\n';
}
function mapper(type){
 if(type.endsWith('?'))return ` (Object? value) => wireNullable(value, ${mapper(type.slice(0,-1))})`;
 if(type.startsWith('List<'))return `(Object? value) => wireList(value, ${mapper(type.slice(5,-1))})`;
 return {String:'wireString',int:'wireInt',bool:'wireBool',double:'wireDouble',Uri:'wireUri',DateTime:'parseInstant',Vnd:'parseVnd',DecimalValue:'(Object? value) => DecimalValue(wireString(value))'}[type]??'map'+type;
}
for(const file of files){
 const source=readFileSync(entityRoot+file+'.dart','utf8');
 for(const [,name,body]of source.matchAll(/final class (\w+)[^{]*\{([\s\S]*?)\n\}/g)){
  if(['Page','PageQuery','PropertySearchResult','SignInInput'].includes(name))continue;
  const fields=[...body.matchAll(/final ([\w<>?]+) (\w+);/g)].map(([,type,key])=>({type,key}));
  output+=`\n${name} map${name}(Object? input) {\n  final value=wireObject(input);\n  return ${name}(\n`+fields.map(({type,key})=>`    ${key}: (${["checkedDate","uploadedDate"].includes(key)?(type.endsWith("?")?"(Object? value) => wireNullable(value, parseDate)":"parseDate"):mapper(type)})(wireField(value,'${key}')),`).join('\n')+'\n  );\n}\n';
 }
}
output=output.replace(/if\s*\(([^\n]*)\)\s+throw ([^;\n]+);/g, 'if ($1) { throw $2; }');
writeFileSync('lib/data/mappers/domain_mappers.dart',output);
console.log('Generated domain wire adapters; no domain signature changes.');

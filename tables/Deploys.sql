CREATE SEQUENCE seqDeploys;
CREATE TABLE Deploys (
DeployID integer not null default nextval('seqDeploys'),
SQL text not null,
MD5 char(32) not null,
Diff text not null,
Datestamp timestamptz not null default now(),
PRIMARY KEY (DeployID)
);

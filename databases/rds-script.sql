CREATE TABLE "aws_task" (
    id serial PRIMARY KEY ,
    test_data VARCHAR(255)
    
);

INSERT INTO "aws_task" (test_data) VALUES ('Hello from POSTGRES!!');
SELECT * FROM "aws_task";
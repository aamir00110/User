----led_devices

  CREATE TABLE "LED_DEVICES" 
   (    "DEVICE_ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
    "IP_ADDRESS" VARCHAR2(20) NOT NULL ENABLE, 
    "MAC_ADDRESS" VARCHAR2(20), 
    "DEVICE_NAME" VARCHAR2(100), 
    "LOCATION" VARCHAR2(200), 
    "CURRENT_COLOR" VARCHAR2(20) DEFAULT 'off', 
    "STATUS" VARCHAR2(20) DEFAULT 'offline', 
    "LAST_SEEN" TIMESTAMP (6), 
    "CREATED_AT" TIMESTAMP (6) DEFAULT SYSTIMESTAMP, 
     PRIMARY KEY ("DEVICE_ID")
  USING INDEX  ENABLE, 
     UNIQUE ("IP_ADDRESS")
  USING INDEX  ENABLE
   ) ;
   ---LED_COLOR_LOG
   
     CREATE TABLE "LED_COLOR_LOG" 
   (    "LOG_ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
    "IP_ADDRESS" VARCHAR2(20), 
    "OLD_COLOR" VARCHAR2(20), 
    "NEW_COLOR" VARCHAR2(20), 
    "CHANGED_BY" VARCHAR2(100), 
    "CHANGED_AT" TIMESTAMP (6) DEFAULT SYSTIMESTAMP, 
     PRIMARY KEY ("LOG_ID")
  USING INDEX  ENABLE
   ) ;



----------------FILE UPLOAD PROCEDURE-------------
create or replace PROCEDURE SP_SAVE_ORIGINAL_PHOTO (
    p_blob_file   IN BLOB,
    p_filename    IN VARCHAR2,
    p_folder_path IN VARCHAR2,
    p_photo_id    OUT NUMBER
)
IS
    l_file         UTL_FILE.FILE_TYPE;
    l_buffer       RAW(32767);
    l_amount       PLS_INTEGER := 32767;
    l_pos          PLS_INTEGER := 1;
    l_blob_length  PLS_INTEGER;

    l_extension    VARCHAR2(10);
    l_new_filename VARCHAR2(256);
    l_file_size_kb NUMBER;
BEGIN

    -- Generate Photo ID
    SELECT PHOTO_UPLOADS_SEQ.NEXTVAL
      INTO p_photo_id
      FROM dual;

    -- Get extension
    l_extension :=
        LOWER(
            SUBSTR(
                p_filename,
                INSTR(p_filename, '.', -1) + 1
            )
        );

    -- New filename
    l_new_filename :=
        TO_CHAR(p_photo_id) || '.' || l_extension;

    -- BLOB size
    l_blob_length := DBMS_LOB.GETLENGTH(p_blob_file);

    l_file_size_kb :=
        ROUND(l_blob_length / 1024, 2);

    -- Open Oracle DIRECTORY
    l_file := UTL_FILE.FOPEN(
        'PICTURE',
        l_new_filename,
        'wb',
        32767
    );

    -- Write BLOB to file
    WHILE l_pos <= l_blob_length LOOP

        IF l_pos + l_amount - 1 > l_blob_length THEN
            l_amount := l_blob_length - l_pos + 1;
        END IF;

        DBMS_LOB.READ(
            p_blob_file,
            l_amount,
            l_pos,
            l_buffer
        );

        UTL_FILE.PUT_RAW(
            l_file,
            l_buffer,
            TRUE
        );

        l_pos := l_pos + l_amount;

    END LOOP;

    UTL_FILE.FCLOSE(l_file);

    -- Insert into table
    INSERT INTO PHOTO_UPLOADS (
        PHOTO_ID,
        ORIGINAL_FILENAME,
        LOW_QUALITY_FILENAME,
        FILE_EXTENSION,
        FILE_PATH,
        BLOB_DATA,
        UPLOAD_DATE,
        LOW_QUALITY_CREATED,
        FILE_SIZE_KB,
        LOW_QUALITY_SIZE_KB
    )
    VALUES (
        p_photo_id,
        p_filename,
        NULL,
        l_extension,
        p_folder_path || '\' || l_new_filename,
        p_blob_file,
        SYSDATE,
        NULL,
        l_file_size_kb,
        NULL
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN

        IF UTL_FILE.IS_OPEN(l_file) THEN
            UTL_FILE.FCLOSE(l_file);
        END IF;

        RAISE;

END SP_SAVE_ORIGINAL_PHOTO;
/
